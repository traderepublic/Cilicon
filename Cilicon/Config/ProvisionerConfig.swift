import Foundation

enum ProvisionerConfig: Codable {
    case github(GithubProvisionerConfig)
    case gitlab(GitLabProvisionerConfig)
    case buildkite(BuildkiteAgentProvisionerConfig)
    case script(ScriptProvisionerConfig)

    enum CodingKeys: CodingKey {
        case type
        case config
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ProvisionerType.self, forKey: .type)
        switch type {
        case .github:
            let config = try container.decode(GithubProvisionerConfig.self, forKey: .config)
            self = .github(config)
        case .gitlab:
            let config = try container.decode(GitLabProvisionerConfig.self, forKey: .config)
            self = .gitlab(config)
        case .buildkite:
            let config = try container.decode(BuildkiteAgentProvisionerConfig.self, forKey: .config)
            self = .buildkite(config)
        case .script:
            let config = try container.decode(ScriptProvisionerConfig.self, forKey: .config)
            self = .script(config)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .script(config):
            try container.encode(ProvisionerType.script, forKey: .type)
            try container.encode(config, forKey: .config)
        default:
            // don't need to encode anything else for now
            break
        }
    }

    enum ProvisionerType: String, Codable {
        case github
        case gitlab
        case buildkite
        case script
    }

    var uiRepresentation: String {
        switch self {
        case .github:
            return "GitHub"
        case .gitlab:
            return "GitLab"
        case .buildkite:
            return "Buildkite"
        case .script:
            return "Script"
        }
    }
}
