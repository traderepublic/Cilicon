import Foundation

class GithubService {
    /// The id of the installation within the Trade Republic Organization
    private let accessToken: AccessToken? = nil
    
    private let urlSession: URLSession
    private let acceptHeader = "application/vnd.github+json"
    
    private let decoder: JSONDecoder = {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        return jsonDecoder
    }()
    
    let config: GithubConfig
    let baseURL: URL
    
    init(config: GithubConfig) {
        self.config = config
        self.baseURL = config.apiURL ?? URL(string: "https://api.github.com/")!
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        self.urlSession = URLSession(configuration: config)
    }
    
    func installationsURL() -> URL {
        baseURL
            .appendingPathComponent("app")
            .appendingPathComponent("installations")
    }
    
    func installationFetchURL(installationId: Int) -> URL {
        installationsURL()
            .appendingPathComponent(String(installationId))
            .appendingPathComponent("access_tokens")
    }
    
    func actionsURL() -> URL {
        baseURL
            .appendingPathComponent("orgs")
            .appendingPathComponent(config.organization)
            .appendingPathComponent("actions")
            .appendingPathComponent("runners")
    }
    
    func runnerTokenURL() -> URL {
        actionsURL()
            .appendingPathComponent("registration-token")
    }
    
    func runnerDownloadsURL() -> URL {
        actionsURL()
            .appendingPathComponent("downloads")
    }
    
    func getInstallations() async throws -> [Installation] {
        let jwtToken = try GithubAppAuthHelper.generateJWTToken(pemPath: config.privateKeyPath, appId: config.appId)
        let (data, _) = try await authenticatedRequest(url: installationsURL(),
                                                       method: "GET",
                                                       token: jwtToken)
        let installations = try decoder.decode([Installation].self, from: data)
        return installations
    }
    
    
    func getInstallationToken(installation: Installation) async throws -> AccessToken {
        let url = installationFetchURL(installationId: installation.id)
        let jwtToken = try GithubAppAuthHelper.generateJWTToken(pemPath: config.privateKeyPath, appId: installation.appId)
        return try await postTokenRequest(url: url, token: jwtToken)
    }
    
    func createRunnerToken(token: String) async throws -> AccessToken {
        let url = runnerTokenURL()
        return try await postTokenRequest(url: url, token: token)
    }
    
    func getRunnerDownloadURLs(authToken: AccessToken) async throws -> [RunnerDownload] {
        let (data, _) = try await authenticatedRequest(url: runnerDownloadsURL(),
                                                       method: "GET",
                                                       token: authToken.token)
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
