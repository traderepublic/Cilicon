import Foundation

struct AzurePipelinesProvisionerConfig: Decodable {
    /// The Azure DevOps organization URL, e.g. https://dev.azure.com/myorganization/
    let url: URL
    /// Personal Access Token with Agent Pools (read, manage) scope
    let token: String
    /// The agent pool name. Defaults to `Default`
    let pool: String
    /// The agent work directory. Defaults to `_work`
    let workDirectory: String
    /// The URL where the Azure Pipelines agent tarball can be downloaded.
    /// Defaults to a macOS ARM64 agent from Microsoft's CDN.
    /// Unfortunately, Microsoft does not offer a "latest" download URL.
    let downloadURL: String

    enum CodingKeys: CodingKey {
        case url
        case token
        case pool
        case workDirectory
        case downloadURL
    }

    init(from decoder: Decoder) throws {
        let defaultDownloadURL = "https://download.agent.dev.azure.com/agent/4.271.0/vsts-agent-osx-arm64-4.271.0.tar.gz"

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.url = try container.decode(URL.self, forKey: .url)
        self.token = try container.decode(String.self, forKey: .token)
        self.pool = try container.decodeIfPresent(String.self, forKey: .pool) ?? "Default"
        self.workDirectory = try container.decodeIfPresent(String.self, forKey: .workDirectory) ?? "_work"
        self.downloadURL = try container.decodeIfPresent(String.self, forKey: .downloadURL) ?? defaultDownloadURL
    }
}
