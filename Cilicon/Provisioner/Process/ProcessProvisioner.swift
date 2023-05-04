//
//  TaskProvisioner.swift
//  Cilicon
//
//  Created by Marco Cancellieri on 30.11.22.
//

import Foundation
/// The Process Provisioner will call an executable of your choice. With the bundle path as well as the action ("provision" or "deprovision") as arguments.
class ProcessProvisioner: Provisioner {
    let path: String
    let arguments: [String]
    
    init(path: String, arguments: [String]) {
        self.path = path
        self.arguments = arguments
    }
    
    func provision(bundle: BundleType) async throws {
        try runProcess(bundle: bundle, action: "provision")
    }
    
    func deprovision(bundle: BundleType) async throws {
        try runProcess(bundle: bundle, action: "deprovision")
    }
    
    func runProcess(bundle: BundleType, action: String) throws {
        let executableURL = URL(filePath: (path as NSString).standardizingPath)
        let args = [bundle.url.relativePath, action] + arguments
        let proc = try Process.run(executableURL, arguments: args)
        proc.waitUntilExit()
        let status = proc.terminationStatus
        guard status == 0 else {
            throw ProcessProvisionerError.nonZeroStatus(status: status,
                                                        executable: executableURL,
                                                        arguments: args)
        }
    }
}

enum ProcessProvisionerError: LocalizedError {
    case nonZeroStatus(status: Int32, executable: URL, arguments: [String])
    
    var errorDescription: String? {
        switch self {
        case .nonZeroStatus(let status, let executable, let arguments):
            return "Expected 0 Termination status, got \(status) instead when running \(executable.relativePath) with arguments: \(arguments.joined(separator: " "))"
        }
    }
}
