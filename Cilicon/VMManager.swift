import Citadel
import Combine
import Compression
import Foundation
import OCI
import Virtualization

class VMManager: NSObject, ObservableObject {
    let config: Config
    let masterBundle: VMBundle
    let clonedBundle: VMBundle
    let provisioner: Provisioner?
    let fileManager: FileManager = .default
    var runCounter: Int = 0
    var sshOutput: [String] = []
    var ip: String = ""

    var activeBundle: VMBundle {
        config.editorMode ? masterBundle : clonedBundle
    }

    @Published
    var vmState: VMState = .initializing

    init(config: Config) {
        switch config.provisioner {
        case let .github(gitHubConfig):
            self.provisioner = GitHubActionsProvisioner(config: config, gitHubConfig: gitHubConfig)
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

    @MainActor
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
                        try? fileManager.removeItem(atPath: resolvedPath)
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

    @MainActor
    func start(vm: VZVirtualMachine) async throws {
        runCounter += 1
        try await vm.start()
    }

    @MainActor
    private func cloneBundle() async throws {
        vmState = .copying
        try await Task {
            try removeBundleIfExists()
            try fileManager.copyItem(at: masterBundle.url.resolvingSymlinksInPath(), to: clonedBundle.url)
        }.value
    }

    @MainActor
    private func setupAndRunVirtualMachine() async throws {
        if !config.editorMode {
            try await cloneBundle()
        }
        let vmHelper = VMConfigHelper(vmBundle: activeBundle)
        let vmConfig = try vmHelper.computeRunConfiguration(config: config)
        let virtualMachine = VZVirtualMachine(configuration: vmConfig)
        virtualMachine.delegate = self

        try await virtualMachine.start()
        vmState = .running(virtualMachine)

        if config.editorMode {
            return
        }
        try await Task.sleep(for: .seconds(5))
        self.ip = try LeaseParser.leaseForMacAddress(mac: masterBundle.configuration.macAddress.string).ipAddress

        let client = try await SSHClient.connect(
            host: ip,
            authenticationMethod: .passwordBased(username: config.sshCredentials.username, password: config.sshCredentials.password),
            hostKeyValidator: .acceptAnything(),
            reconnect: .always
        )

        print("IP Address: \(ip)")
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

        if let provisioner {
            do {
                try await provisioner.provision(bundle: activeBundle, sshClient: client)
            } catch {
                print(error.localizedDescription)
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

        SSHLogger.shared.log(string: "---------- Shutting Down ----------\n")
        try await client.close()

        Task { @MainActor in
            try await virtualMachine.stop()
            try await handleStop()
        }
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

    @MainActor
    func handleStop() async throws {
        if config.editorMode {
            // In editor mode we don't want to reboot or restart the VM
            NSApplication.shared.terminate(nil)
            return
        }
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

        switch imgLayers.first?.mediaType {
        case "application/vnd.cirruslabs.tart.disk.v2":
            try await LayerV2Downloader.pull(
                registry: client,
                diskLayers: imgLayers,
                diskURL: diskURL,
                maxConcurrency: 4,
                progress: prog
            )
        default:
            try await LayerV1Downloader.pull(
                registry: client,
                diskLayers: imgLayers,
                diskURL: diskURL,
                maxConcurrency: 0,
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

extension VMManager: VZVirtualMachineDelegate {
    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        print("Virtual machine did stop with error: \(error.localizedDescription)")
        Task {
            try await self.handleStop()
        }
    }

    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        print("Guest did stop virtual machine.")
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
}

extension VMManagerError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .masterBundleNotFound(path):
            return "Could not found bundle at \(path)"
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
