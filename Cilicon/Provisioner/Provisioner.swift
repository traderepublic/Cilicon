import Foundation

protocol Provisioner {
    func provision(bundle: VMBundle) async throws
    func deprovision(bundle: VMBundle) async throws
}
