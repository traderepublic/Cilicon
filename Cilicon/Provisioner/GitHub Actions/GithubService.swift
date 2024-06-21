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

    let config: GithubProvisionerConfig
    let baseURL: URL

    init(config: GithubProvisionerConfig) {
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

    var runnersURL: URL {
        if let repo = config.repository {
            return repoRunnersURL(repo: repo)
        }
        return orgRunnersURL
    }

    private var orgRunnersURL: URL {
        baseURL
            .appendingPathComponent("orgs")
            .appendingPathComponent(config.organization)
            .appendingPathComponent("actions")
            .appendingPathComponent("runners")
    }

    private func repoRunnersURL(repo: String) -> URL {
        baseURL
            .appendingPathComponent("repos")
            .appendingPathComponent(config.organization)
            .appendingPathComponent(repo)
            .appendingPathComponent("actions")
            .appendingPathComponent("runners")
    }

    func runnerTokenURL() -> URL {
        runnersURL
            .appendingPathComponent("registration-token")
    }

    func runnerJitConfigURL() -> URL {
        runnersURL
            .appendingPathComponent("generate-jitconfig")
    }

    func runnerDownloadsURL() -> URL {
        runnersURL
            .appendingPathComponent("downloads")
    }

    func getInstallation(keyPath: String) async throws -> Installation {
        let jwtToken = try GithubAppAuthHelper.generateJWTToken(pemPath: keyPath, appId: config.appId)
        return try await authenticatedRequest(
            url: installationURL,
            token: jwtToken,
            responseType: Installation.self
        )
    }

    func getAuthToken() async throws -> String {
        let installation = try await getInstallation(keyPath: config.privateKeyPath)
        let token = try await getInstallationToken(
            installation: installation,
            keyPath: config.privateKeyPath
        )
        return token.token
    }

    func getInstallationToken(installation: Installation, keyPath: String) async throws -> AccessToken {
        let url = installationFetchURL(installationId: installation.id)
        let jwtToken = try GithubAppAuthHelper.generateJWTToken(pemPath: keyPath, appId: installation.appId)
        return try await postTokenRequest(url: url, token: jwtToken)
    }

    func getRunners(name: String, token: String) async throws -> [Runner] {
        return try await authenticatedRequest(
            url: runnersURL,
            query: ["name": name],
            token: token,
            responseType: RunnersResponse.self
        ).runners
    }

    func deleteRunner(id: Int, token: String) async throws {
        _ = try await authenticatedRequest(
            url: runnersURL.appendingPathComponent("\(id)"),
            method: "DELETE",
            token: token
        )
        return
    }

    func createRunnerToken(token: String) async throws -> AccessToken {
        let url = runnerTokenURL()
        return try await postTokenRequest(url: url, token: token)
    }

    func createJitRunnerToken(body: Encodable, token: String) async throws -> String {
        let url = runnerJitConfigURL()
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let jitBody = try encoder.encode(body)
        return try await authenticatedRequest(
            url: url,
            body: jitBody,
            method: "POST",
            token: token,
            responseType: JitConfigResponse.self
        )
        .encodedJitConfig
    }

    func getRunnerDownloadURLs(authToken: String) async throws -> [RunnerDownload] {
        return try await authenticatedRequest(
            url: runnerDownloadsURL(),
            token: authToken,
            responseType: [RunnerDownload].self
        )
    }

    private func authenticatedRequest(
        url: URL,
        query: [String: String] = [:],
        body: Data? = nil,
        method: String = "GET",
        token: String
    ) async throws -> Data {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.url?.append(queryItems: query.map { URLQueryItem(name: $0, value: $1) })
        urlRequest.setValue(acceptHeader, forHTTPHeaderField: "Accept")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = body
        let (data, response) = try await urlSession.data(for: urlRequest) as! (Data, HTTPURLResponse)
        guard 200 ..< 300 ~= response.statusCode else {
            throw GithubServiceError.non200(data)
        }
        return data
    }

    private func authenticatedRequest<T: Decodable>(
        url: URL,
        query: [String: String] = [:],
        body: Data? = nil,
        method: String = "GET",
        token: String,
        responseType: T.Type
    ) async throws -> T {
        let data = try await authenticatedRequest(
            url: url,
            query: query,
            body: body,
            method: method,
            token: token
        )
        return try decoder.decode(responseType, from: data)
    }

    private func postTokenRequest(url: URL, token: String) async throws -> AccessToken {
        return try await authenticatedRequest(
            url: url,
            method: "POST",
            token: token,
            responseType: AccessToken.self
        )
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

struct JitConfigResponse: Decodable {
    let encodedJitConfig: String
}

enum GithubServiceError: LocalizedError {
    case non200(Data)
    var errorDescription: String? {
        switch self {
        case let .non200(data):
            return String(data: data, encoding: .utf8)
        }
    }
}

struct RunnersResponse: Decodable {
    let runners: [Runner]
}

struct Runner: Decodable {
    let id: Int
    let name: String
}
