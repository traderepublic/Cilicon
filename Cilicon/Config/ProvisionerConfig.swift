import Foundation

enum ProvisionerConfig: Decodable {
    case github(GitHubProvisionerConfig)
    case gitlab(GitLabProvisionerConfig)
    case buildkite(BuildkiteAgentProvisionerConfig)
    case process(ScriptProvisionerConfig)
    case none
    
    enum CodingKeys: CodingKey {
        case type
        case config
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ProvisionerType.self, forKey: .type)
        switch type {
        case .github:
            let config = try container.decode(GitHubProvisionerConfig.self, forKey: .config)
            self = .github(config)
        case .gitlab:
            let config = try container.decode(GitLabProvisionerConfig.self, forKey: .config)
            self = .gitlab(config)
        case .buildkite:
            let config = try container.decode(BuildkiteAgentProvisionerConfig.self, forKey: .config)
            self = .buildkite(config)
        case .script:
            let config = try container.decode(ScriptProvisionerConfig.self, forKey: .config)
            self = .process(config)
            
        case .none:
            self = .none
        }
    }
    
    enum ProvisionerType: String, Decodable {
        case github
        case gitlab
        case buildkite
        case script
        case none
    }
}
