import Foundation
import Virtualization

class VMManager: NSObject, ObservableObject {
    let config: Config
    let masterBundle: Bundle
    let clonedBundle: Bundle
    let provisioner: Provisioner?
    let fileManager: FileManager = .default
    var runCounter: Int = 0
    let copier: ImageCopier
    
    var activeBundle: Bundle {
        config.editorMode ? masterBundle : clonedBundle
    }
    
    @Published
    var vmState: VMState = .initializing
    
    init(config: Config) {
        switch config.provisioner {
        case .github(let gitHubConfig):
            self.provisioner = GitHubActionsProvisioner(config: config, gitHubConfig: gitHubConfig)
        case .gitlab(let gitLabconfig):
            self.provisioner = GitLabRunnerProvisioner(config: config, gitLabConfig: gitLabconfig)
        case .process(let processConfig):
            self.provisioner = ProcessProvisioner(path: processConfig.executablePath, arguments: processConfig.arguments)
        case .none:
            self.provisioner = nil
        }
        self.config = config
        self.copier = ImageCopier(config: config)
        switch config.vmBundleType {
        case .cilicon:
            self.masterBundle = .cilicon(VMBundle(url: URL(filePath: config.vmBundlePath)))
            self.clonedBundle = .cilicon(VMBundle(url: URL(filePath: config.vmClonePath)))
        case .tart:
            self.masterBundle = .tart(TartBundle(url: URL(filePath: config.vmBundlePath)))
            self.clonedBundle = .tart(TartBundle(url: URL(filePath: config.vmClonePath)))
        }
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
            try fileManager.copyItem(at: masterBundle.common.url, to: clonedBundle.common.url)
        }.value
    }
    
    @MainActor
    func setupAndRunVirtualMachine() async throws {
        if copier.isCopying {
            vmState = .copyingFromVolume
            print("Copying bundle from external Volume. Retrying in 10 seconds.")
            try await Task.sleep(for: .seconds(10))
            try await setupAndRunVirtualMachine()
        }
        if !config.editorMode {
            try await cloneBundle()
            if let provisioner = provisioner {
                vmState = .provisioning
                try activeBundle.common.resourcesURL.createIfNotExists()
                try await provisioner.provision(bundle: activeBundle.common)
            }
        }
        let vmHelper = VMConfigHelper(vmBundle: activeBundle)
        let vmConfig = try vmHelper.computeRunConfiguration(config: config)
        let virtualMachine = VZVirtualMachine(configuration: vmConfig)
        virtualMachine.delegate = self
        vmState = .running(virtualMachine)
        try await virtualMachine.start()
    }
    
    @MainActor
    func handleStop() async throws {
        try await provisioner?.deprovision(bundle: activeBundle.common)
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
        if fileManager.fileExists(atPath: clonedBundle.common.url.relativePath) {
            try fileManager.removeItem(atPath: clonedBundle.common.url.relativePath)
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
