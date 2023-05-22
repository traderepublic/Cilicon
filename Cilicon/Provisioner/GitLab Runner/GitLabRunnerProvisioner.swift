import Foundation
import Citadel

class GitLabRunnerProvisioner: Provisioner {
    let config: Config
    let runnerConfig: GitLabProvisionerConfig
    let service: GitLabService
    let fileManager: FileManager
    
    private var runnerToken: String?
    
    init(config: Config, gitLabConfig: GitLabProvisionerConfig, fileManager: FileManager = .default) {
        self.config = config
        self.runnerConfig = gitLabConfig
        self.service = GitLabService(config: gitLabConfig)
        self.fileManager = fileManager
    }
    
    func provision(bundle: VMBundle, sshClient: SSHClient) async throws {
        let registration = try await service.registerRunner()
        try setRunnerEndpointURL(bundle: bundle, url: runnerConfig.url)
        try setRunnerToken(bundle: bundle, token: registration.token)
        self.runnerToken = registration.token
    }
    
    func deprovision(bundle: VMBundle, sshClient: SSHClient) async throws {
        if let runnerToken {
            try await service.deregisterRunner(runnerToken: runnerToken)
        } else {
            print("Nothing to deregister, skipping...")
        }
        return
    }
    
    private func setRunnerEndpointURL(bundle: VMBundle, url: URL) throws {
//        let tokenPath = bundle.runnerEndpointURL.relativePath
//        guard fileManager.createFile(atPath: tokenPath, contents: url.absoluteString.data(using: .utf8)) else {
//            throw GitLabRunnerProvisioner.Error.couldNotCreateRunnerTokenFile(path: tokenPath)
//        }
    }

    private func setRunnerToken(bundle: VMBundle, token: String) throws {
//        let tokenPath = bundle.runnerTokenURL.relativePath
//        guard fileManager.createFile(atPath: tokenPath, contents: token.data(using: .utf8)) else {
//            throw GitLabRunnerProvisioner.Error.couldNotCreateRunnerTokenFile(path: tokenPath)
//        }
    }
}

extension GitLabRunnerProvisioner {
    enum Error: Swift.Error {
        case couldNotCreateRunnerTokenFile(path: String)
        case couldNotCreateRunnerEndpointFile(path: String)
        case invalidConfiguration(reason: String)
    }
}

extension GitLabRunnerProvisioner.Error: LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .couldNotCreateRunnerTokenFile(path):
            return "Could not create Runner Token File at \(path)"
        case let .couldNotCreateRunnerEndpointFile(path):
            return "Could not create Runner Endpoint File at \(path)"
        case let .invalidConfiguration(reason):
            return "Configuration invalid: \(reason)"
        }
    }
}
