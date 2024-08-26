import Citadel
import Foundation

class GitLabRunnerProvisioner: Provisioner {
    let config: GitLabProvisionerConfig

    init(config: GitLabProvisionerConfig) {
        self.config = config
    }

    func provision(sshClient: SSHClient, sshLogger: SSHLogger) async throws {
        var downloadCommands: [String] = []

        sshLogger.log(string: "Configuring GitLab Runner...".magentaBold)
        let copyConfigTomlCommand = """
        mkdir -p ~/.gitlab-runner
        rm -rf ~/.gitlab-runner/config.toml
        cat <<'EOF' >> ~/.gitlab-runner/config.toml
        [[runners]]
          url = "\(config.gitlabURL)"
          token = "\(config.runnerToken)"
          executor = "\(config.executor)"
          limit = \(config.maxNumberOfBuilds)
        \(config.configToml ?? "")
        EOF
        exit 1
        """
        try await executeCommand(command: copyConfigTomlCommand, sshClient: sshClient, sshLogger: sshLogger)
        sshLogger.log(string: "Successfully configured GitLab Runner".greenBold)

        if config.downloadLatest {
            sshLogger.log(string: "Downloading GitLab Runner Binary from Source".magentaBold)
            downloadCommands = [
                "rm -rf gitlab-runner",
                "curl -o gitlab-runner \(config.downloadURL)",
                "sudo chmod +x gitlab-runner"
            ]
            try await executeCommand(command: downloadCommands.joined(separator: " && "), sshClient: sshClient, sshLogger: sshLogger)
            sshLogger.log(string: "Downloaded GitLab Runner Binary from Source successfully".magentaBold)
        } else {
            sshLogger.log(string: "Skipped downloading GitLab Runner Binary because downloadLatest is false".magentaBold)
        }

        let runCommand = "gitlab-runner run"
        sshLogger.log(string: "Starting GitLab Runner...".magentaBold)
        try await executeCommand(command: runCommand, sshClient: sshClient, sshLogger: sshLogger)
    }

    private func executeCommand(command: String, sshClient: SSHClient, sshLogger: SSHLogger) async throws {
        let streamOutput = try await sshClient.executeCommandStream(command, inShell: true)
        for try await blob in streamOutput {
            switch blob {
            case let .stdout(stdout):
                sshLogger.log(string: String(buffer: stdout))
            case let .stderr(stderr):
                sshLogger.log(string: String(buffer: stderr))
            }
        }
    }
}

/// Shell output color values
private extension String {
    var greenBold: String { "\u{001B}[1;32m\(self)\u{001B}[0m\n" }
    var magentaBold: String { "\u{001B}[1;35m\(self)\u{001B}[0m\n" }
}
