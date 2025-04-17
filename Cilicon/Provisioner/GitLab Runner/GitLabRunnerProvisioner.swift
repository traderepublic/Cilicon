import Citadel
import Foundation

class GitLabRunnerProvisioner: Provisioner {
    let config: GitLabProvisionerConfig

    init(config: GitLabProvisionerConfig) {
        self.config = config
    }

    func provision(bundle: VMBundle, sshClient: SSHClient) async throws {
        if config.downloadLatest {
            await SSHLogger.shared.log(string: "Downloading GitLab Runner Binary".magentaBold)
            let downloadCommand = """
            curl -o gitlab-runner \(config.downloadURL) && chmod +x gitlab-runner
            """
            try await executeCommand(command: downloadCommand, sshClient: sshClient)
            await SSHLogger.shared.log(string: "Downloaded GitLab Runner Binary".magentaBold)
        } else {
            await SSHLogger.shared.log(string: "Skipped downloading GitLab Runner Binary because downloadLatest is false".magentaBold)
        }
        let registerCommand = """
        ./gitlab-runner run-single \
        --token \(config.runnerToken) \
        --url \(config.gitlabURL) \
        --executor \(config.executor) \
        --max-builds \(config.maxNumberOfBuilds)
        """
        try await executeCommand(command: registerCommand, sshClient: sshClient)
    }

    private func executeCommand(command: String, sshClient: SSHClient) async throws {
        let streamOutput = try await sshClient.executeCommandStream(command, inShell: true)
        for try await blob in streamOutput {
            switch blob {
            case let .stdout(stdout):
                await SSHLogger.shared.log(string: String(buffer: stdout))
            case let .stderr(stderr):
                await SSHLogger.shared.log(string: String(buffer: stderr))
            }
        }
    }
}

/// Shell output color values
private extension String {
    var greenBold: String { "\u{001B}[1;32m\(self)\u{001B}[0m\n" }
    var magentaBold: String { "\u{001B}[1;35m\(self)\u{001B}[0m\n" }
}
