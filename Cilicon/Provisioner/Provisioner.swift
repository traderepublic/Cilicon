import Foundation

protocol Provisioner {
    func provision(bundle: BundleType) async throws
    func deprovision(bundle: BundleType) async throws
}
