@preconcurrency import Citadel
import Foundation

class AzurePipelinesProvisioner: Provisioner {
    let config: Config
    let azurePipelinesConfig: AzurePipelinesProvisionerConfig

    var agentName: String {
        config.runnerName ?? Host.current().localizedName ?? "cilicon-agent"
    }

    init(config: Config, azurePipelinesConfig: AzurePipelinesProvisionerConfig) {
        self.config = config
        self.azurePipelinesConfig = azurePipelinesConfig
    }

    func provision(bundle: VMBundle, sshClient: SSHClient) async throws {
        let commands: [String] = [
            "mkdir -p ~/azpagent && cd ~/azpagent",
            "curl -sL -o agent.tar.gz \(azurePipelinesConfig.downloadURL)",
            "tar xzf agent.tar.gz",
            "export VSO_AGENT_IGNORE=AZP_TOKEN,AZP_TOKEN_FILE",
            """
            ./config.sh --unattended \
            --url \(azurePipelinesConfig.url) \
            --auth pat \
            --token \(azurePipelinesConfig.token) \
            --pool \(azurePipelinesConfig.pool) \
            --agent \(agentName) \
            --work \(azurePipelinesConfig.workDirectory) \
            --replace \
            --acceptTeeEula
            """,
            "./run.sh --once",
        ]

        let command = commands.joined(separator: " && ")
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
