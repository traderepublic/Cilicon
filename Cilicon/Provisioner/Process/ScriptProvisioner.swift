import Foundation
import Citadel
/// The Process Provisioner will call an executable of your choice. With the bundle path as well as the action ("provision" or "deprovision") as arguments.
class ScriptProvisioner: Provisioner {
    let runBlock: String
    
    init(runBlock: String) {
        self.runBlock = runBlock}
    
    func provision(bundle: VMBundle, sshClient: SSHClient) async throws {
        let streams = try await sshClient.executeCommandStream(runBlock)
        var asyncStreams = streams.makeAsyncIterator()
        
        while let blob = try await asyncStreams.next() {
            switch blob {
            case .stdout(let stdout):
                SSHLogger.shared.log(string: String(buffer: stdout))
            case .stderr(let stderr):
                SSHLogger.shared.log(string: String(buffer: stderr))
            }
        }
        try await sshClient.close()
    }
}
