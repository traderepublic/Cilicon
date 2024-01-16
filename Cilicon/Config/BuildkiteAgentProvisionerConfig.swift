import Foundation

struct BuildkiteAgentProvisionerConfig: Decodable {
    let agentToken: String
    let tags: [String]

    enum CodingKeys: CodingKey {
        case agentToken
        case tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.agentToken = try container.decode(String.self, forKey: .agentToken)
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
    }
}
