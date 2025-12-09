@preconcurrency import Citadel
import Combine
import Compression
import Foundation
import Virtualization

@MainActor
final class VMManager: NSObject, ObservableObject {
    let config: Config
    let masterBundle: VMBundle
    let clonedBundle: VMBundle
    let provisioner: Provisioner?
    let fileManager: FileManager = .default
    var runCounter: Int = 0
    var sshOutput: [String] = []
    var ip: String = ""
    var livenessProbeTask: Task<Void, Never>?

    var activeBundle: VMBundle {
        clonedBundle
    }

    @Published
    var vmState: VMState = .initializing

    init(config: Config) {
        switch config.provisioner {
        case let .github(githubConfig):
            self.provisioner = GithubActionsProvisioner(config: config, githubConfig: githubConfig)
        case let .gitlab(gitLabConfig):
            self.provisioner = GitLabRunnerProvisioner(config: gitLabConfig)
        case let .buildkite(buildkiteConfig):
            self.provisioner = BuildkiteAgentProvisioner(config: buildkiteConfig)
        case let .script(scriptConfig):
            self.provisioner = ScriptProvisioner(runBlock: scriptConfig.run)
        }
        self.config = config
        self.masterBundle = VMBundle(url: URL(filePath: config.source.localPath))
        self.clonedBundle = VMBundle(url: URL(filePath: config.vmClonePath))
    }

    func setupAndRunVM() async throws {
        do {
            vmState = .initializing
            if masterBundle.isLegacy {
                vmState = .legacyWarning(path: masterBundle.url.path)
                return
            }

            if case let .OCI(ociURL) = config.source {
                let resolvedPath = masterBundle.url.resolvingSymlinksInPath().path
                if try fileManager.fileExists(atPath: resolvedPath) && !isBundleComplete() {
                    try fileManager.removeItem(atPath: resolvedPath)
                }
                if !fileManager.fileExists(atPath: resolvedPath) {
                    try await withTaskCancellationHandler(operation: {
                        try await downloadFromOCI(url: ociURL)
                    }, onCancel: {
                        Task { @MainActor in
                            try? fileManager.removeItem(atPath: resolvedPath)
                        }
                    })
                }
            }
            try await setupAndRunVirtualMachine()
        } catch {
            vmState = .failed(error.localizedDescription)
            try await Task.sleep(for: .seconds(config.retryDelay))
            try await setupAndRunVM()
        }
    }

    func start(vm: VZVirtualMachine) async throws {
        runCounter += 1
        try await vm.start()
    }

    private func cloneBundle() async throws {
        vmState = .copying
        try await Task {
            try removeBundleIfExists()
            try fileManager.copyItem(at: masterBundle.url.resolvingSymlinksInPath(), to: clonedBundle.url)
        }.value
    }

    private func fetchIP(macAddress: String) async throws -> String {
        var leaseTries = 0

        while true {
            let ipResult = Result {
                try LeaseParser.leaseForMacAddress(mac: macAddress).ipAddress
            }
            switch ipResult {
            case let .success(ip):
                return ip
            case let .failure(err):
                if leaseTries >= 5 {
                    throw err
                }
                try await Task.sleep(for: .seconds(5))
                leaseTries += 1
            }
        }
    }

    private func setupAndRunVirtualMachine() async throws {
        try await cloneBundle()
        let vmHelper = VMConfigHelper(vmBundle: activeBundle)
        let vmConfig = try vmHelper.computeRunConfiguration(config: config)
        let virtualMachine = VZVirtualMachine(configuration: vmConfig)
        virtualMachine.delegate = self

        SSHLogger.shared.log(string: "---------- Starting Up ----------\n")
        try await virtualMachine.start()
        vmState = .running(virtualMachine)
        self.ip = try await fetchIP(macAddress: clonedBundle.configuration.macAddress.string)

        // Wait for VM to fully boot and can execute SSH commands before proceeding
        let client = try await createAndConnectSSHClient(ip: ip)

        if let preRun = config.preRun {
            let streamOutput = try await client.executeCommandStream(preRun, inShell: true)
            for try await blob in streamOutput {
                switch blob {
                case let .stdout(stdout):
                    SSHLogger.shared.log(string: String(buffer: stdout))
                case let .stderr(stderr):
                    SSHLogger.shared.log(string: String(buffer: stderr))
                }
            }
        }

        // Start liveness probe after preRun completes
        if let livenessProbe = config.provisioner.livenessProbe {
            startLivenessProbe(livenessProbe: livenessProbe, virtualMachine: virtualMachine)
        }

        if let provisioner {
            do {
                try await provisioner.provision(bundle: activeBundle, sshClient: client)
            } catch {
                SSHLogger.shared.log(string: error.localizedDescription + "\n")
            }
        }

        if let postRun = config.postRun {
            let streamOutput = try await client.executeCommandStream(postRun, inShell: true)
            for try await blob in streamOutput {
                switch blob {
                case let .stdout(stdout):
                    SSHLogger.shared.log(string: String(buffer: stdout))
                case let .stderr(stderr):
                    SSHLogger.shared.log(string: String(buffer: stderr))
                }
            }
        }
        try await client.close()

        // Cancel liveness probe before shutting down
        livenessProbeTask?.cancel()
        livenessProbeTask = nil

        SSHLogger.shared.log(string: "---------- Shutting Down ----------\n")
        Task { @MainActor in
            try await virtualMachine.stop()
            try await handleStop()
        }
    }

    /// Creates and connects an SSH client to the given IP address, retrying until successful or a timeout occurs.
    private func createAndConnectSSHClient(ip: String) async throws -> SSHClient {
        SSHLogger.shared.log(string: "Waiting for VM to boot and SSH to be available...\n")
        let maxRetries = config.sshConnectMaxRetries
        var tries = 0

        while tries < maxRetries {
            do {
                let client = try await SSHClient.connect(
                    host: ip,
                    authenticationMethod: .passwordBased(
                        username: config.sshCredentials.username,
                        password: config.sshCredentials.password
                    ),
                    hostKeyValidator: .acceptAnything(),
                    reconnect: .never,
                    connectTimeout: .seconds(5)
                )

                // Test if we can execute a simple command
                let token = "ssh-connected"
                let streamOutput = try await client.executeCommandStream("echo \(token)", inShell: true)
                var commandSuccessful = false

                for try await blob in streamOutput {
                    switch blob {
                    case let .stdout(stdout):
                        let output = String(buffer: stdout)
                        if output.contains(token) {
                            commandSuccessful = true
                        }
                    case .stderr:
                        break
                    }
                }

                if commandSuccessful {
                    SSHLogger.shared.log(string: "VM fully booted and SSH available\n")
                    return client
                }

                try await client.close()
            } catch {
                // SSH not ready yet, continue waiting
                tries += 1
                SSHLogger.shared.log(string: "SSH connect \(tries)/\(maxRetries): SSH not ready, waiting 5s...\n")
                try await Task.sleep(for: .seconds(5))
            }
        }

        throw VMManagerError.sshConnectTimeout
    }

    func isBundleComplete() throws -> Bool {
        let filesExist = [
            masterBundle.diskImageURL,
            masterBundle.configURL,
            masterBundle.auxiliaryStorageURL
        ]
            .map { $0.resolvingSymlinksInPath() }
            .reduce(into: false) { $0 = fileManager.fileExists(atPath: $1.path) }
        let notUnfinished = !fileManager.fileExists(atPath: masterBundle.unfinishedURL.path)

        return filesExist && notUnfinished
    }

    func handleStop() async throws {
        if let runsTilReboot = config.numberOfRunsUntilHostReboot, runCounter >= runsTilReboot {
            AppleEvent.restart.perform()
            NSApplication.shared.terminate(nil)
            return
        }
        vmState = .provisioning
        Task {
            try await setupAndRunVirtualMachine()
        }
    }

    func removeBundleIfExists() throws {
        if fileManager.fileExists(atPath: clonedBundle.url.relativePath) {
            try fileManager.removeItem(atPath: clonedBundle.url.relativePath)
        }
    }

    func cleanup() throws {
        livenessProbeTask?.cancel()
        livenessProbeTask = nil
        try removeBundleIfExists()
    }

    func downloadFromOCI(url: OCIURL) async throws {
        let client = OCI(url: url)
        let (digest, manifest) = try await client.fetchManifest()
        let path = URL(filePath: url.localPath).deletingLastPathComponent().appending(path: digest)
        try fileManager.createDirectory(at: path, withIntermediateDirectories: true)

        if !fileManager.fileExists(atPath: url.localPath) {
            try fileManager.createSymbolicLink(at: URL(filePath: url.localPath), withDestinationURL: path)
        }
        fileManager.createFile(atPath: masterBundle.unfinishedURL.path, contents: nil)
        let bundleForPaths = VMBundle(url: path)

        guard let configLayer = manifest.layers.first(where: { $0.mediaType == "application/vnd.cirruslabs.tart.config.v1" }) else {
            fatalError()
        }

        Task { @MainActor in
            vmState = .downloading(text: "config", progress: 0)
        }
        let configData = try await client.pullBlobData(digest: configLayer.digest)
        try configData.write(to: bundleForPaths.configURL)
        // Fetching images

        let totalSize = manifest.layers.map(\.size).reduce(into: Int64(0), +=)

        let diskURL = bundleForPaths.diskImageURL

        let imgLayers = manifest.layers.filter { $0.mediaType.starts(with: "application/vnd.cirruslabs.tart.disk.") }

        let prog = Progress()
        prog.totalUnitCount = totalSize
        let progCanc = prog
            .publisher(for: \.fractionCompleted)
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] in
                self?.vmState = .downloading(text: "layers", progress: $0)
            })
        // trigger state update
        prog.completedUnitCount = 0

        let fm = FileManager.default
        if fm.fileExists(atPath: diskURL.path) {
            try fm.removeItem(at: diskURL)
        }
        if !fm.createFile(atPath: diskURL.path, contents: nil) {
            throw VMManagerError.failedToCreateDiskFile
        }

        let isV2Disk = imgLayers.allSatisfy({ $0.mediaType == "application/vnd.cirruslabs.tart.disk.v2" })

        if isV2Disk {
            try await LayerV2Downloader.pull(
                registry: client,
                diskLayers: imgLayers,
                diskURL: diskURL,
                progress: prog,
                maxConcurrency: 4
            )
        } else {
            try await LayerV1Downloader.pull(
                registry: client,
                diskLayers: imgLayers,
                diskURL: diskURL,
                progress: prog
            )
        }

        progCanc.cancel()

        // Getting NVRAM
        Task { @MainActor in
            vmState = .downloading(text: "NVRAM", progress: 0)
        }
        guard let nvramLayer = manifest.layers.first(where: { $0.mediaType == "application/vnd.cirruslabs.tart.nvram.v1" }) else {
            fatalError()
        }
        let nvramData = try await client.pullBlobData(digest: nvramLayer.digest)
        try nvramData.write(to: bundleForPaths.auxiliaryStorageURL)
        try fileManager.removeItem(at: masterBundle.unfinishedURL)
    }
}

// MARK: - Liveness Probe

private extension VMManager {
    /// Starts a liveness probe that periodically checks VM health and restarts on failure
    private func startLivenessProbe(livenessProbe: LivenessProbeConfig, virtualMachine: VZVirtualMachine) {
        livenessProbeTask = Task { @MainActor in
            SSHLogger.shared.log(string: "[1;34mLiveness probe starting in \(livenessProbe.delay) seconds[0m\n")

            // Initial delay before starting probes
            try? await Task.sleep(for: .seconds(livenessProbe.delay))

            guard !Task.isCancelled else { return }

            SSHLogger.shared.log(string: "[1;34mLiveness probe active (interval: \(livenessProbe.interval)s)[0m\n")

            while !Task.isCancelled {
                do {
                    // Create a new SSH client for the probe
                    let probeClient = try await SSHClient.connect(
                        host: ip,
                        authenticationMethod: .passwordBased(
                            username: config.sshCredentials.username,
                            password: config.sshCredentials.password
                        ),
                        hostKeyValidator: .acceptAnything(),
                        reconnect: .never,
                        connectTimeout: .seconds(5)
                    )

                    // Execute the liveness probe command and check exit code
                    // We use a wrapper command that explicitly outputs the exit code
                    let wrappedCommand = "\(livenessProbe.command); echo \"EXIT_CODE:$?\""
                    let streamOutput = try await probeClient.executeCommandStream(wrappedCommand, inShell: true)

                    var outputBuffer = ""
                    for try await blob in streamOutput {
                        switch blob {
                        case let .stdout(stdout):
                            outputBuffer += String(buffer: stdout)
                        case .stderr:
                            break
                        }
                    }

                    try await probeClient.close()

                    // Extract exit code from output
                    var exitCode = 1
                    if let exitCodeMatch = outputBuffer.range(of: "EXIT_CODE:(\\d+)", options: .regularExpression) {
                        let exitCodeString = outputBuffer[exitCodeMatch].replacingOccurrences(of: "EXIT_CODE:", with: "")
                        exitCode = Int(exitCodeString.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1
                    }

                    guard exitCode == 0 else {
                        SSHLogger.shared.log(string: "[1;31mLiveness probe failed with exit code \(exitCode), restarting VM[0m\n")

                        // Cancel this task to prevent further probes
                        livenessProbeTask?.cancel()
                        livenessProbeTask = nil

                        // Stop and restart the VM
                        try await virtualMachine.stop()
                        try await handleStop()
                        return
                    }

                    // Wait for the next probe interval
                    try await Task.sleep(for: .seconds(livenessProbe.interval))
                } catch is CancellationError {
                    // Task was cancelled, exit cleanly
                    return
                } catch {
                    // Log SSH or command execution errors but don't restart
                    // This allows temporary network issues without triggering restarts
                    SSHLogger.shared.log(string: "[1;33mLiveness probe error (will retry): \(error.localizedDescription)[0m\n")
                    try? await Task.sleep(for: .seconds(livenessProbe.interval))
                }
            }
        }
    }
}

// MARK: - VZVirtualMachineDelegate

extension VMManager: VZVirtualMachineDelegate {
    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        print("Virtual machine did stop with error: \(error.localizedDescription)")
        livenessProbeTask?.cancel()
        livenessProbeTask = nil
        Task {
            try await self.handleStop()
        }
    }

    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        print("Guest did stop virtual machine.")
        livenessProbeTask?.cancel()
        livenessProbeTask = nil
        Task {
            try await self.handleStop()
        }
    }
}

extension VMManager {
    func upgradeImageFromLegacy() {
        do {
            try LegacyVMBundle(url: masterBundle.url).upgrade()
            Task.detached {
                try await self.setupAndRunVM()
            }
        } catch {
            vmState = .legacyUpgradeFailed
        }
    }
}

enum VMManagerError: Error {
    case masterBundleNotFound(path: String)
    case failedToCreateDiskFile
    case sshConnectTimeout
}

extension VMManagerError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .masterBundleNotFound(path):
            return "Could not found bundle at \(path)"
        case .failedToCreateDiskFile:
            return "Failed to create Disk File"
        case .sshConnectTimeout:
            return "SSH Connect timeout"
        }
    }
}

enum VMState {
    case initializing
    case failed(String)
    case copying
    case copyingFromVolume
    case provisioning
    case running(VZVirtualMachine)
    case downloading(text: String, progress: Double)
    case legacyWarning(path: String)
    case legacyUpgradeFailed
}
