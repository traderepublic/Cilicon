import Foundation

class GitlabRunnerProvisioner: Provisioner {
    let config: Config
    let runnerConfig: GitlabProvisionerConfig
    let service: GitlabService
    let fileManager: FileManager
    
    private var runnerToken: String?
    
    init(config: Config, gitlabConfig: GitlabProvisionerConfig, fileManager: FileManager = .default) {
        self.config = config
        self.runnerConfig = gitlabConfig
        self.service = GitlabService(config: gitlabConfig)
        self.fileManager = fileManager
    }
    
    func provision(bundle: VMBundle) async throws {
        let registration = try await service.registerRunner()
        try setRunnerEndpointURL(bundle: bundle, url: runnerConfig.url)
        try setRunnerToken(bundle: bundle, token: registration.token)
        self.runnerToken = registration.token
    }
    
    func deprovision(bundle: VMBundle) async throws {
        if let runnerToken {
            try await service.deregisterRunner(runnerToken: runnerToken)
        } else {
            print("Nothing to deregister, skipping...")
        }
        return
    }
    
    private func setRunnerEndpointURL(bundle: VMBundle, url: URL) throws {
        let tokenPath = bundle.runnerEndpointURL.relativePath
        guard fileManager.createFile(atPath: tokenPath, contents: url.absoluteString.data(using: .utf8)) else {
            throw GitlabRunnerProvisioner.Error.couldNotCreateRunnerTokenFile(path: tokenPath)
        }
    }

    private func setRunnerToken(bundle: VMBundle, token: String) throws {
        let tokenPath = bundle.runnerTokenURL.relativePath
        guard fileManager.createFile(atPath: tokenPath, contents: token.data(using: .utf8)) else {
            throw GitlabRunnerProvisioner.Error.couldNotCreateRunnerTokenFile(path: tokenPath)
        }
    }
}

extension GitlabRunnerProvisioner {
    enum Error: Swift.Error {
        case couldNotCreateRunnerTokenFile(path: String)
        case couldNotCreateRunnerEndpointFile(path: String)
        case invalidConfiguration(reason: String)
    }
}

extension GitlabRunnerProvisioner.Error: LocalizedError {
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


fileprivate extension VMBundle {
    var runnerTokenURL: URL {
        resourcesURL.appending(component: "RUNNER_TOKEN")
    }
    
    var runnerEndpointURL: URL {
        resourcesURL.appending(component: "RUNNER_ENDPOINT_URL")
    }
}
