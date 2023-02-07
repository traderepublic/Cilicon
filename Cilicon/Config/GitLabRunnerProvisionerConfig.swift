import Foundation

struct GitLabRunnerProvisionerConfig: Decodable {
    
    /// The name by which the runner can be identified
    let name: String
    /// The url to register the runner at. In a self-hosted environment, this is probably your main GitLab URL, e.g. https://gitlab.yourdomain.net/
    let url: URL
    /// The runner registration token, can be obtained in the GitLab runner UI
    let registrationToken: String
    /// The GitLab Executor, for a macOS or iOS CI Environment, use `shell` executor
    let executor: String
    /// A list of tags to apply to the runner, comma-separated
    let tagList: String

    enum CodingKeys: CodingKey {
        case executablePath
        case name
        case url
        case registrationToken
        case executor
        case tagList
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.url = try container.decode(URL.self, forKey: .url)
        self.registrationToken = try container.decode(String.self, forKey: .registrationToken)
        self.executor = try container.decode(String.self, forKey: .executor)
        self.tagList = try container.decode(String.self, forKey: .tagList)
    }
}
