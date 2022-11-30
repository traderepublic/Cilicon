import Foundation

enum ProvisionerConfig: Decodable {
    case github(GithubConfig)
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
            let config = try container.decode(GithubConfig.self, forKey: .config)
            self = .github(config)
        case .none:
            self = .none
        }
    }
    
    enum ProvisionerType: String, Decodable {
        case github
        case none
    }
}
