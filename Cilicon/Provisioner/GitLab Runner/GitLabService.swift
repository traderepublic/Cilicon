import Foundation

class GitLabService {
    private let urlSession: URLSession
    let config: GitLabProvisionerConfig
    let baseURL: URL
    
    init(config: GitLabProvisionerConfig) {
        self.config = config
        self.baseURL = config.url
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        self.urlSession = URLSession(configuration: config)
    }
    
    private func apiURL() -> URL {
        baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("v4")
    }
    
    private func runnersURL() -> URL {
        apiURL()
            .appendingPathComponent("runners")
    }
}

// MARK: Methods

extension GitLabService {
    func registerRunner() async throws -> RunnerRegistrationResponse {
        let registration = RunnerRegistration(registrationToken: config.registrationToken,
                                              description: config.name,
                                              tags: config.tagList.components(separatedBy: ","))
        let jsonData = try encode(registration)
        let (data, response) = try await postRequest(to: runnersURL(), jsonData: jsonData)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Error.couldNotRegisterRunner(reason: "Expected a HTTP Response, got \(response)")
        }
        
        guard httpResponse.statusCode == 201 else {
            throw Error.couldNotRegisterRunner(reason: "Got response code \(httpResponse.statusCode), expected to receive 201 instead.")
        }
        
        guard let registrationResponse: RunnerRegistrationResponse = try? decode(data) else {
            throw Error.couldNotRegisterRunner(reason: "Could not decode the response")
        }
        
        return registrationResponse
    }
    
    func deregisterRunner(runnerToken token: String) async throws {
        let deletion = RunnerDeletion(token: token)
        let jsonData = try encode(deletion)
        
        let (_, response) = try await deleteRequest(to: runnersURL(), jsonData: jsonData)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Error.couldNotDeleteRunner(reason: "Expected a HTTP Response, got \(response)")
        }
        
        guard httpResponse.statusCode == 204 else {
            throw Error.couldNotDeleteRunner(reason: "Got response code \(httpResponse.statusCode), expected to receive 204 instead.")
        }
    }
}

// MARK: Requests

private extension GitLabService {
    private func postRequest(to url: URL, jsonData: Data) async throws -> (Data, URLResponse) {
        return try await makeRequest(to: url, method: "POST", jsonData: jsonData)
    }
    
    private func deleteRequest(to url: URL, jsonData: Data) async throws -> (Data, URLResponse) {
        return try await makeRequest(to: url, method: "DELETE", jsonData: jsonData)
    }
    
    private func makeRequest(to url: URL, method: String, jsonData: Data) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        return try await urlSession.data(for: request)
    }
}

// MARK: Codable

private extension GitLabService {
    private func encode(_ encodable: Encodable) throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(encodable)
    }
    
    private func decode<T: Decodable>(_ decodable: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: decodable)
    }
}

// MARK: Models

extension GitLabService {
    private struct RunnerRegistration: Codable {
        let registrationToken: String
        let description: String
        let tags: [String]
        
        enum CodingKeys: String, CodingKey {
            case registrationToken = "token"
            case description
            case tags = "tag_list"
        }
    }
    
    public struct RunnerRegistrationResponse: Decodable {
        let id: Int
        let token: String
    }
    
    private struct RunnerDeletion: Codable {
        let token: String
    }
}

extension GitLabService {
    enum Error: Swift.Error {
        case couldNotRegisterRunner(reason: String)
        case couldNotDeleteRunner(reason: String)
    }
}

extension GitLabService.Error: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .couldNotRegisterRunner(let reason):
            return "Could not register runner: \(reason)"
        case .couldNotDeleteRunner(let reason):
            return "Could not delete runner: \(reason)"
        }
    }
}

