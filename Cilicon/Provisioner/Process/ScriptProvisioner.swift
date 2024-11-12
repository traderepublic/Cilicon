import Foundation

/// The Process Provisioner will call an executable of your choice. With the bundle path as well as the action ("provision" or "deprovision") as
/// arguments.
class ScriptProvisioner: Provisioner {
    let runBlock: String

    init(runBlock: String) {
        self.runBlock = runBlock
    }

    func provision(bundle: VMBundle, sshClient: SSHClient) async throws {
        let streamOutput = try await sshClient.executeCommandStream(runBlock)
        for try await blob in streamOutput {
            switch blob {
            case let .stdout(stdout):
                await SSHLogger.shared.log(string: stdout)
            case let .stderr(stderr):
                await SSHLogger.shared.log(string: stderr)
            }
        }
    }
}
