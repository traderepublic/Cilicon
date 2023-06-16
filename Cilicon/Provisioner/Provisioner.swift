import Citadel
import Foundation

protocol Provisioner {
    func provision(bundle: VMBundle, sshClient: SSHClient) async throws
}
