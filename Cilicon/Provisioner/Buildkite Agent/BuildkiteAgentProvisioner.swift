import Foundation
import Citadel
/// The Buildkite Provisioner
class BuildkiteAgentProvisioner: Provisioner {
    let agentToken: String
    let tags: [String]
    
    init(config: BuildkiteAgentProvisionerConfig) {
        self.agentToken = config.agentToken
        self.tags = config.tags
    }
    
    func provision(bundle: VMBundle, sshClient: SSHClient) async throws {
        var block = """
        TOKEN="\(agentToken)" bash -c "`curl -sL https://raw.githubusercontent.com/buildkite/agent/main/install.sh`"
        ~/.buildkite-agent/bin/buildkite-agent start --disconnect-after-job
        """
        
        if !tags.isEmpty {
            block.append(" --tags \(tags.joined(separator: ","))")
        }
        
        let streams = try await sshClient.executeCommandStream(block)
        var asyncStreams = streams.makeAsyncIterator()
        
        while let blob = try await asyncStreams.next() {
            switch blob {
            case .stdout(let stdout):
                SSHLogger.shared.log(string: String(buffer: stdout))
            case .stderr(let stderr):
                SSHLogger.shared.log(string: String(buffer: stderr))
            }
        }
        try await sshClient.close()
    }
}
