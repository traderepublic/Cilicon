import Citadel
import Foundation
import Semaphore
import Virtualization

let vmSemaphore = AsyncSemaphore(value: 1)
@Observable
class VMRunner: NSObject, Identifiable, VZVirtualMachineDelegate {
    var state: State = .idle
    let provisioner: Provisioner?
    let config: Config
    let machineConfig: MachineConfig
    let fileManager = FileManager()
    let macAddress: VZMACAddress
    let sshLogger = SSHLogger()
    let id: String

    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: any Error) {
        print("did stop with error")
        print(error.localizedDescription)
    }

    init(config: Config, vmConfig: VMRunnerConfig) {
        switch vmConfig.machineConfig.provisioner {
        case let .github(githubConfig):
            self.provisioner = GithubActionsProvisioner(
                config: vmConfig.machineConfig,
                githubConfig: githubConfig
            )
        case let .gitlab(gitLabConfig):
            self.provisioner = GitLabRunnerProvisioner(config: gitLabConfig)
        case let .buildkite(buildkiteConfig):
            self.provisioner = BuildkiteAgentProvisioner(config: buildkiteConfig)
        case let .script(scriptConfig):
            self.provisioner = ScriptProvisioner(runBlock: scriptConfig.run)
        }
        self.config = config
        self.id = vmConfig.machineConfig.id
        self.machineConfig = vmConfig.machineConfig
        self.macAddress = VZMACAddress(string: vmConfig.macAddress)!
    }

    @MainActor
    func startVM(vm: VZVirtualMachine) async throws {
        await vmSemaphore.wait()
        defer { vmSemaphore.signal() }
        try await vm.start()
    }

    @MainActor
    func stopVM(vm: VZVirtualMachine) async throws {
        await vmSemaphore.wait()
        defer { vmSemaphore.signal() }
        guard vm.canStop else { return }
        try await vm.stop()
    }

    var runTask: Task<Void, Error>?
    func forceStop() {
        runTask?.cancel()
        runTask = nil
    }

    func start() async throws {
        let task = Task(priority: .background) {
            do {
                // Get Source
                await setState(state: .fetching)
                let source = machineConfig.source
                let path = try await SourceManager.shared.getPath(source: source)
                // Clone Source
                await setState(state: .cloning)
                let clonedURL = try cloneSource(at: path.path)
                // Run VM
                let bundle = VMBundle(url: clonedURL)
                let vmHelper = VMConfigHelper(vmBundle: bundle)
                let vmConfig = try vmHelper.computeRunConfiguration(
                    config: machineConfig,
                    macAddress: macAddress
                )
                let virtualMachine = VZVirtualMachine(configuration: vmConfig)
                virtualMachine.delegate = self
                try await startVM(vm: virtualMachine)
                await setState(state: .running(virtualMachine, .connecting))
                let ip = try await fetchIP()
                try Task.checkCancellation()
                let client = try await SSHClient.connect(
                    host: ip,
                    authenticationMethod: .passwordBased(
                        username: machineConfig.sshCredentials.username,
                        password: machineConfig.sshCredentials.password
                    ),
                    hostKeyValidator: .acceptAnything(),
                    reconnect: .never,
                    connectTimeout: .seconds(60)
                )

                if let preRun = machineConfig.preRun {
                    await setState(state: .running(virtualMachine, .preRun))
                    try await provisioner?.runCommand(cmd: preRun, sshClient: client, sshLogger: sshLogger)
                }
                if let provisioner {
                    await setState(state: .running(virtualMachine, .provisioning))
                    try await provisioner.provision(sshClient: client, sshLogger: sshLogger)
                }

                if let postRun = machineConfig.postRun {
                    await setState(state: .running(virtualMachine, .postRun))
                    try await provisioner?.runCommand(cmd: postRun, sshClient: client, sshLogger: sshLogger)
                }
                await setState(state: .running(virtualMachine, .shutdown))
                try await stopVM(vm: virtualMachine)
                await setState(state: .cleanup)
                try cleanup()
            } catch {
                await setState(state: .failed(error.localizedDescription))
                throw error
            }
        }
        runTask = task

        switch await task.result {
        case .success:
            break
        case let .failure(err):
            if err is CancellationError {
                if case let .running(vm, _) = state {
                    try await stopVM(vm: vm)
                }
                try cleanup()
                await setState(state: .canceled)
            } else {
                throw err
            }
        }
    }

    private func fetchIP() async throws -> String {
        var leaseTries = 0
        while true {
            try Task.checkCancellation()
            let ipResult = Result {
                try LeaseParser.leaseForMacAddress(mac: macAddress.string).ipAddress
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

    var cloneDirectoryPath: String {
        config.clonePath ?? NSString("~/cilicon-clones/").expandingTildeInPath
    }

    var clonePath: String {
        cloneDirectoryPath + "/" + machineConfig.id + "/"
    }

    private func cloneSource(at source: String) throws -> URL {
        if !fileManager.fileExists(atPath: cloneDirectoryPath) {
            try fileManager.createDirectory(atPath: cloneDirectoryPath, withIntermediateDirectories: true)
        }

        if fileManager.fileExists(atPath: clonePath) {
            try fileManager.removeItem(atPath: clonePath)
        }
        try fileManager.copyItem(atPath: source, toPath: clonePath)
        return URL(filePath: clonePath)
    }

    private func cleanup() throws {
        try fileManager.removeItem(atPath: clonePath)
    }

    @MainActor
    func setState(state: State) {
        self.state = state
    }

    enum State {
        case fetching
        case idle
        case cloning
        case running(VZVirtualMachine, RunState)
        case stopping
        case cleanup
        case canceled
        case failed(String)

        var isRunning: Bool {
            if case .running = self {
                return true
            }
            return false
        }
    }

    enum RunState {
        case connecting
        case provisioning
        case preRun
        case postRun
        case shutdown
    }
}

struct VMRunnerConfig {
    let macAddress: String = VZMACAddress.randomLocallyAdministered().string
    let machineConfig: MachineConfig
}
