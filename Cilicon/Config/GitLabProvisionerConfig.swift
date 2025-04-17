import Foundation

struct GitLabProvisionerConfig: Decodable {
    /// The url to register the runner at. In a self-hosted environment, this is probably your main GitLab URL, e.g. https://gitlab.yourdomain.net/
    let gitlabURL: URL
    /// The runner token, can be obtained in the GitLab Admin UI when creating a new runner
    /// - note: The runner token begins with `glrt-`
    let runnerToken: String
    /// The executor to use. Defaults to `shell`
    let executor: String
    /// The maximum number of builds to process. Defaults to `1`
    /// Using `0` sets no limit to the number of builds. In this case, the Cilicon instance will not be restarted automatically.
    let maxNumberOfBuilds: Int
    /// Whether the latest gitlab-runner binary should be downloaded. Defaults to `true`
    let downloadLatest: Bool
    /// The URL where the gitlab-runner binary can be downloaded
    /// Only used if `downloadLatest` is set to `true`
    /// Defaults to the latest macOS binary from GitLab's S3 bucket
    let downloadURL: String
    /// If this is set, the other runner related variables are ignored.
    /// Instead, the toml file specified will be used to configure the runner.
    let tomlPath: String?

    enum CodingKeys: CodingKey {
        case gitlabURL
        case runnerToken
        case executor
        case maxNumberOfBuilds
        case downloadLatest
        case downloadURL
        case tomlPath
    }

    init(from decoder: Decoder) throws {
        let defaultDownloadURL = "https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-darwin-arm64"

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.gitlabURL = try container.decode(URL.self, forKey: .gitlabURL)
        self.runnerToken = try container.decode(String.self, forKey: .runnerToken)
        self.executor = try container.decodeIfPresent(String.self, forKey: .executor) ?? "shell"
        self.maxNumberOfBuilds = try container.decodeIfPresent(Int.self, forKey: .maxNumberOfBuilds) ?? 1
        self.downloadLatest = try container.decodeIfPresent(Bool.self, forKey: .downloadLatest) ?? true
        self.downloadURL = try container.decodeIfPresent(String.self, forKey: .downloadURL) ?? defaultDownloadURL
        self.tomlPath = try container.decodeIfPresent(String.self, forKey: .tomlPath)
    }
}
