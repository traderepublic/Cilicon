import Foundation
import Virtualization
import Citadel

class VMManager: NSObject, ObservableObject {
    let config: Config
    let masterBundle: VMBundle
    let clonedBundle: VMBundle
    let provisioner: Provisioner?
    let fileManager: FileManager = .default
    var runCounter: Int = 0
    let copier: ImageCopier
    var sshOutput: [String] = []
    
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
        case .process(let scriptConfig):
            self.provisioner = ScriptProvisioner(runBlock: scriptConfig.run)
        case .none:
            self.provisioner = nil
        }
        self.config = config
        self.copier = ImageCopier(config: config)
        self.masterBundle = VMBundle(url: URL(filePath: config.vmBundlePath))
        self.clonedBundle = VMBundle(url: URL(filePath: config.vmClonePath))
    }
    
    @MainActor
    func setupAndRunVM() async throws {
        do {
            vmState = .initializing
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
    
    
    func setupAndRunVirtualMachine() async throws {
        if copier.isCopying {
            vmState = .copyingFromVolume
            print("Copying bundle from external Volume. Retrying in 10 seconds.")
            try await Task.sleep(for: .seconds(10))
            try await setupAndRunVirtualMachine()
        }
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
        try await Task.sleep(for: .seconds(5))
        guard let ip = LeaseParser.leaseForMacAddress(mac: masterBundle.configuration.macAddress.string)?.ipAddress else {
            return
        }
        
        let client = try await SSHClient.connect(
            host: ip,
            authenticationMethod: .passwordBased(username: config.sshCredentials.username, password: config.sshCredentials.password),
            hostKeyValidator: .acceptAnything(),
            reconnect: .always
        )
        print("IP Address: \(ip)")
        if let preRun = config.preRun {
            let streams = try await client.executeCommandStream(preRun)
            var asyncStreams = streams.makeAsyncIterator()
            
            while let blob = try await asyncStreams.next() {
                switch blob {
                case .stdout(let stdout):
                    await SSHLogger.shared.log(string: String(buffer: stdout))
                case .stderr(let stderr):
                    await SSHLogger.shared.log(string: String(buffer: stderr))
                }
            }
        }
        
        if let provisioner = provisioner {
            try await provisioner.provision(bundle: activeBundle, sshClient: client)
        }
        
        if let postRun = config.postRun {
            let streams = try await client.executeCommandStream(postRun)
            var asyncStreams = streams.makeAsyncIterator()
            
            while let blob = try await asyncStreams.next() {
                switch blob {
                case .stdout(let stdout):
                    await SSHLogger.shared.log(string: String(buffer: stdout))
                case .stderr(let stderr):
                    await SSHLogger.shared.log(string: String(buffer: stderr))
                }
            }
        }
//
//        try await client.close()
//
//        Task { @MainActor in
//            try await virtualMachine.stop()
//            try await handleStop()
//        }
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
}
