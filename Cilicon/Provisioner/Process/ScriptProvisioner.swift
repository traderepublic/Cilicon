import Foundation
import Citadel
/// The Process Provisioner will call an executable of your choice. With the bundle path as well as the action ("provision" or "deprovision") as arguments.
class ScriptProvisioner: Provisioner {
    let runBlock: String
    
    init(runBlock: String) {
        self.runBlock = runBlock
    }
    
    func provision(bundle: VMBundle, sshClient: SSHClient) async throws {
        let streamOutput = try await sshClient.executeCommandStream(runBlock, inShell: true)
        for try await blob in streamOutput {
            switch blob {
            case .stdout(let stdout):
                await SSHLogger.shared.log(string: String(buffer: stdout))
            case .stderr(let stderr):
                await SSHLogger.shared.log(string: String(buffer: stderr))
            }
        }
    }
}
