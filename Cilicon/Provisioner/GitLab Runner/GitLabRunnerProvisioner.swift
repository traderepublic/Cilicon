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
        var block = """
        sudo curl --output /usr/local/bin/gitlab-runner https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-darwin-arm64
        sudo chmod +x /usr/local/bin/gitlab-runner
        
        /usr/local/bin/gitlab-runner run-single -u \(runnerConfig.url.absoluteString) -t \(runnerConfig.registrationToken) --executor shell --max-builds 1
        """
        
        if let name = runnerConfig.name ?? Host.current().localizedName {
            block.append(" --name '\(name)'")
        }
        
        let streamOutput = try await sshClient.executeCommandStream(block, inShell: true)
        for try await blob in streamOutput {
            switch blob {
            case .stdout(let stdout):
                await SSHLogger.shared.log(string: String(buffer: stdout))
            case .stderr(let stderr):
                await SSHLogger.shared.log(string: String(buffer: stderr))
            }
        }
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
