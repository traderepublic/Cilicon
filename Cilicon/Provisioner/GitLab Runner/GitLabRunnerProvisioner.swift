import Citadel
import Foundation

class GitLabRunnerProvisioner: Provisioner {
    let config: GitLabProvisionerConfig

    init(config: GitLabProvisionerConfig) {
        self.config = config
    }

    func provision(bundle: VMBundle, sshClient: SSHClient) async throws {
        var downloadCommands: [String] = []

        if config.downloadLatest {
            await SSHLogger.shared.log(string: "[1;35mDownloading GitLab Runner Binary from Source[0m\n")
            downloadCommands = [
                "rm -rf gitlab-runner",
                "curl -o gitlab-runner \(config.downloadURL)",
                "sudo chmod +x gitlab-runner"
            ]
        }

        let runCommand = """
            gitlab-runner run-single \
                -u \(config.gitlabURL.absoluteString) \
                -t \(config.runnerToken) \
                --executor \(config.executor) \
                --max-builds \(config.maxNumberOfBuilds)
        """

        let command = (downloadCommands + [runCommand]).joined(separator: " && ")

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
