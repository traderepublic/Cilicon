import Citadel
import Foundation

/// The Buildkite Provisioner
class BuildkiteAgentProvisioner: Provisioner {
    let agentToken: String
    let tags: [String]

    init(config: BuildkiteAgentProvisionerConfig) {
        self.agentToken = config.agentToken
        self.tags = config.tags
    }

    func provision(sshClient: SSHClient, sshLogger: SSHLogger) async throws {
        var block = """
        TOKEN="\(agentToken)" bash -c "`curl -sL https://raw.githubusercontent.com/buildkite/agent/main/install.sh`"
        ~/.buildkite-agent/bin/buildkite-agent start --disconnect-after-job
        """

        if !tags.isEmpty {
            block.append(" --tags \(tags.joined(separator: ","))")
        }

        let streamOutput = try await sshClient.executeCommandStream(block, inShell: true)
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
