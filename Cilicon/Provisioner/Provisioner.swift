import Foundation
import Citadel

protocol Provisioner {
    func provision(bundle: VMBundle, sshClient: SSHClient) async throws
}
