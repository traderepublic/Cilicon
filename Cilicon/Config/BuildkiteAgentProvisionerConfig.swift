import Foundation
struct BuildkiteAgentProvisionerConfig: Decodable {
    let agentToken: String
    let tags: [String]
}
