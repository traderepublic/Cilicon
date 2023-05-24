import Foundation
import Virtualization
import Citadel
import OCI
import Compression

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
        case .github(let gitHubConfig):
            self.provisioner = GitHubActionsProvisioner(config: config, gitHubConfig: gitHubConfig)
        case .gitlab(let gitLabConfig):
            self.provisioner = GitLabRunnerProvisioner(config: config, gitLabConfig: gitLabConfig)
        case .buildkite(let buildkiteConfig):
            self.provisioner = BuildkiteAgentProvisioner(config: buildkiteConfig)
        case .script(let scriptConfig):
            self.provisioner = ScriptProvisioner(runBlock: scriptConfig.run)
        case .none:
            self.provisioner = nil
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
        }
        catch {
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
    
    
    private func setupAndRunVirtualMachine() async throws {
        if !config.editorMode {
            try await cloneBundle()
        }
        let vmHelper = VMConfigHelper(vmBundle: activeBundle)
        let vmConfig = try vmHelper.computeRunConfiguration(config: config)
        let virtualMachine = VZVirtualMachine(configuration: vmConfig)
        virtualMachine.delegate = self
        
        Task { @MainActor in
            vmState = .running(virtualMachine)
            try await virtualMachine.start()
        }
        if config.editorMode {
            return
        }
        try await Task.sleep(for: .seconds(5))
        guard let ip = LeaseParser.leaseForMacAddress(mac: masterBundle.configuration.macAddress.string)?.ipAddress else {
            return
        }
        self.ip = ip
        
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
                case .stdout(let stdout):
                    await SSHLogger.shared.log(string: String(buffer: stdout))
                case .stderr(let stderr):
                    await SSHLogger.shared.log(string: String(buffer: stderr))
                }
            }
        }
        
        if let provisioner = provisioner {
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
                case .stdout(let stdout):
                    await SSHLogger.shared.log(string: String(buffer: stdout))
                case .stderr(let stderr):
                    await SSHLogger.shared.log(string: String(buffer: stderr))
                }
            }
        }
        
        await SSHLogger.shared.log(string: "---------- Shutting Down ----------\n")
        try await client.close()

        Task { @MainActor in
            try await virtualMachine.stop()
            try await handleStop()
        }
    }
    
    
    func isBundleComplete() throws -> Bool {
        let filesExist = [masterBundle.diskImageURL,
                          masterBundle.configURL,
                          masterBundle.auxiliaryStorageURL]
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
            vmState = .downloading(text: "config.json", progress: 0)
        }
        let configData = try await client.pullBlobData(digest: configLayer.digest)
        try configData.write(to: bundleForPaths.configURL)
        // Fetching images
        
        let totalSize = manifest.layers.map(\.size).reduce(into: Int64(0), +=)
        
        let bufferSizeBytes = 64 * 1024 * 1024
        
        let diskURL = bundleForPaths.diskImageURL
        fileManager.createFile(atPath: diskURL.path, contents: nil)
        
        let disk = try FileHandle(forWritingTo: diskURL)
        let filter = try OutputFilter(.decompress, using: .lz4, bufferCapacity: bufferSizeBytes) { data in
          if let data = data {
            disk.write(data)
          }
        }
        
        let imgLayers = manifest.layers.filter { $0.mediaType == "application/vnd.cirruslabs.tart.disk.v1" }
        var lastDataCount = 0
        var lastProgress: Double = -1
        for (index, layer) in imgLayers.enumerated() {
            var data = Data()
            data.reserveCapacity(Int(layer.size))
            for try await byte in try await client.pullBlob(digest: layer.digest) {
                data.append(byte)
                let progress = Double(data.count + lastDataCount) / Double(totalSize)
                if progress - lastProgress > 0.001 {
                    lastProgress = progress
                    Task { @MainActor in
                        vmState = .downloading(text: "disk image layer \(index+1)/\(imgLayers.count)", progress: progress)
                    }
                }
            }
            lastDataCount += data.count
            try filter.write(data)
        }
        try filter.finalize()
        try disk.close()
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

