import Foundation

enum ProvisionerConfig: Decodable {
    case github(GithubProvisionerConfig)
    case gitlab(GitLabRunnerProvisionerConfig)
    case process(ProcessProvisionerConfig)
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
            let config = try container.decode(GithubProvisionerConfig.self, forKey: .config)
            self = .github(config)
        case .gitlab:
            let config = try container.decode(GitLabRunnerProvisionerConfig.self, forKey: .config)
            self = .gitlab(config)
        case .process:
            let config = try container.decode(ProcessProvisionerConfig.self, forKey: .config)
            self = .process(config)
        case .none:
            self = .none
        }
    }
    
    enum ProvisionerType: String, Decodable {
        case github
        case gitlab
        case process
        case none
    }
}
