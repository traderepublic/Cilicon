import Foundation

class GitHubService {
    /// The id of the installation within the Trade Republic Organization
    private let accessToken: AccessToken? = nil

    private let urlSession: URLSession
    private let acceptHeader = "application/vnd.github+json"

    private let decoder: JSONDecoder = {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        return jsonDecoder
    }()

    let config: GitHubProvisionerConfig
    let baseURL: URL

    init(config: GitHubProvisionerConfig) {
        self.config = config
        self.baseURL = config.apiURL ?? URL(string: "https://api.github.com/")!
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        self.urlSession = URLSession(configuration: config)
    }

    private var orgInstallationURL: URL {
        baseURL
            .appendingPathComponent("orgs")
            .appendingPathComponent(config.organization)
            .appendingPathComponent("installation")
    }

    private func repoInstallationURL(repo: String) -> URL {
        baseURL
            .appendingPathComponent("repos")
            .appendingPathComponent(config.organization)
            .appendingPathComponent(repo)
            .appendingPathComponent("installation")
    }

    var installationURL: URL {
        if let repo = config.repository {
            return repoInstallationURL(repo: repo)
        }
        return orgInstallationURL
    }

    func installationFetchURL(installationId: Int) -> URL {
        baseURL
            .appendingPathComponent("app")
            .appendingPathComponent("installations")
            .appendingPathComponent(String(installationId))
            .appendingPathComponent("access_tokens")
    }

    var actionsURL: URL {
        if let repo = config.repository {
            return repoActionsURL(repo: repo)
        }
        return orgActionsURL
    }

    private var orgActionsURL: URL {
        baseURL
            .appendingPathComponent("orgs")
            .appendingPathComponent(config.organization)
            .appendingPathComponent("actions")
            .appendingPathComponent("runners")
    }

    private func repoActionsURL(repo: String) -> URL {
        baseURL
            .appendingPathComponent("repos")
            .appendingPathComponent(config.organization)
            .appendingPathComponent(repo)
            .appendingPathComponent("actions")
            .appendingPathComponent("runners")
    }

    func runnerTokenURL() -> URL {
        actionsURL
            .appendingPathComponent("registration-token")
    }

    func runnerDownloadsURL() -> URL {
        actionsURL
            .appendingPathComponent("downloads")
    }

    func getInstallation() async throws -> Installation {
        let jwtToken = try GitHubAppAuthHelper.generateJWTToken(pemPath: config.privateKeyPath, appId: config.appId)
        let (data, _) = try await authenticatedRequest(
            url: installationURL,
            method: "GET",
            token: jwtToken
        )
        let installation = try decoder.decode(Installation.self, from: data)
        return installation
    }

    func getInstallationToken(installation: Installation) async throws -> AccessToken {
        let url = installationFetchURL(installationId: installation.id)
        let jwtToken = try GitHubAppAuthHelper.generateJWTToken(pemPath: config.privateKeyPath, appId: installation.appId)
        return try await postTokenRequest(url: url, token: jwtToken)
    }

    func createRunnerToken(token: String) async throws -> AccessToken {
        let url = runnerTokenURL()
        return try await postTokenRequest(url: url, token: token)
    }

    func getRunnerDownloadURLs(authToken: AccessToken) async throws -> [RunnerDownload] {
        let (data, _) = try await authenticatedRequest(
            url: runnerDownloadsURL(),
            method: "GET",
            token: authToken.token
        )
        return try decoder.decode([RunnerDownload].self, from: data)
    }

    private func authenticatedRequest(url: URL, method: String, token: String) async throws -> (Data, URLResponse) {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue(acceptHeader, forHTTPHeaderField: "Accept")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await urlSession.data(for: urlRequest)
    }

    private func postTokenRequest(url: URL, token: String) async throws -> AccessToken {
        let (data, _) = try await authenticatedRequest(url: url, method: "POST", token: token)
        let token = try decoder.decode(AccessToken.self, from: data)
        return token
    }
}

struct AccessToken: Decodable {
    let token: String
}

struct Installation: Decodable {
    let id: Int
    let appId: Int
    let account: InstallationAccount
}

struct InstallationAccount: Decodable {
    let login: String
}

struct RunnerDownload: Decodable {
    let os: String
    let architecture: String
    let downloadUrl: URL
    let filename: String
}
