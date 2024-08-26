import Citadel
import Foundation

/// The Process Provisioner will call an executable of your choice. With the bundle path as well as the action ("provision" or "deprovision") as
/// arguments.
class ScriptProvisioner: Provisioner {
    let runBlock: String

    init(runBlock: String) {
        self.runBlock = runBlock
    }

    func provision(sshClient: SSHClient, sshLogger: SSHLogger) async throws {
        try await runCommand(cmd: runBlock, sshClient: sshClient, sshLogger: sshLogger)
    }
}
