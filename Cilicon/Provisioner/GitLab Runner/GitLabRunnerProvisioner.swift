import Citadel
import Foundation

class GitLabRunnerProvisioner: Provisioner {
    let config: GitLabProvisionerConfig

    init(config: GitLabProvisionerConfig) {
        self.config = config
    }

    func provision(bundle: VMBundle, sshClient: SSHClient) async throws {
        var downloadCommands: [String] = []

        await SSHLogger.shared.log(string: "Copying config.toml to VM".magentaBold)
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

        do {
            try await executeCommand(command: copyConfigTomlCommand, sshClient: sshClient)
        } catch {
            fatalError(error.localizedDescription)
        }
        await SSHLogger.shared.log(string: "Copied config.toml successfully".greenBold)

        if config.downloadLatest {
            await SSHLogger.shared.log(string: "Downloading GitLab Runner Binary from Source".magentaBold)
            downloadCommands = [
                "rm -rf gitlab-runner",
                "curl -o gitlab-runner \(config.downloadURL)",
                "sudo chmod +x gitlab-runner"
            ]
            try await executeCommand(command: downloadCommands.joined(separator: " && "), sshClient: sshClient)
            await SSHLogger.shared.log(string: "Downloaded GitLab Runner Binary from Source successfully".magentaBold)
        } else {
            await SSHLogger.shared.log(string: "Skipped downloading GitLab Runner Binary because downloadLatest is false".magentaBold)
        }

        let runCommand = "gitlab-runner run"
        await SSHLogger.shared.log(string: "Starting GitLab Runner...".magentaBold)
        try await executeCommand(command: runCommand, sshClient: sshClient)
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
