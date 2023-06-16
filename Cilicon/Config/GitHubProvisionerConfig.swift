import Foundation

struct GitHubProvisionerConfig: Decodable {
    /// The GitHub API URL. Will be `https://api.github.com/` in most cases
    let apiURL: URL?
    /// The App Id of the installed application with Organization "Self-hosted runners" Read & Write access.
    let appId: Int
    /// The organization slug
    let organization: String
    /// Path to the private key `.pem` file downloaded from the Github App page
    let privateKeyPath: String
    /// Extra labels to add to the runner
    let extraLabels: [String]?
    /// Default: `true`
    let downloadLatest: Bool

    let runnerGroup: String?

    let organizationURL: URL

    enum CodingKeys: CodingKey {
        case apiURL
        case appId
        case organization
        case privateKeyPath
        case extraLabels
        case runnerGroup
        case organizationURL
        case downloadLatest
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.apiURL = try container.decodeIfPresent(URL.self, forKey: .apiURL)
        self.appId = try container.decode(Int.self, forKey: .appId)
        self.organization = try container.decode(String.self, forKey: .organization)
        self.privateKeyPath = (try container.decode(String.self, forKey: .privateKeyPath) as NSString).standardizingPath
        self.extraLabels = try container.decodeIfPresent([String].self, forKey: .extraLabels)
        self.runnerGroup = try container.decodeIfPresent(String.self, forKey: .runnerGroup)
        self.organizationURL = try container.decodeIfPresent(URL.self, forKey: .organizationURL) ?? URL(string: "https://github.com/\(organization)")!
        self.downloadLatest = try container.decodeIfPresent(Bool.self, forKey: .downloadLatest) ?? true
    }
}
