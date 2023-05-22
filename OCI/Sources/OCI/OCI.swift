import Foundation
public struct OCI {
    let url: OCIURL
    
    var baseURL: URL {
        URL(string: "https://\(url.registry)/v2\(url.repository)")!
    }
    
    public init(url: OCIURL) {
        self.url = url
    }
    
    let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = false
        return URLSession(configuration: config)
    }()
    
    public func fetchManifest(authentication: AuthenticationType = .none) async throws -> (String, Manifest) {
        let manifestURL = baseURL.appending(path: "manifests/\(url.tag)")
        let headers = [
            "Accept": "application/vnd.oci.image.manifest.v1+json"
        ]
        let (data, response) = try await request(authentication: authentication, url: manifestURL, headers: headers)
        let contentDigest = response.value(forHTTPHeaderField: "docker-content-digest")!
        let jsonDecoder = JSONDecoder()
        return (contentDigest, try jsonDecoder.decode(Manifest.self, from: data))
    }
    
    public func pullBlob(digest: String, authentication: AuthenticationType = .none) async throws -> URLSession.AsyncBytes {
        let blobUrl = baseURL.appending(path: "blobs/\(digest)")
        let (data, _) = try await download(authentication: authentication, url: blobUrl)
        return data
    }
    
    public func pullBlobData(digest: String, authentication: AuthenticationType = .none) async throws -> Data {
        let blobUrl = baseURL.appending(path: "blobs/\(digest)")
        let (data, _) = try await request(authentication: authentication, url: blobUrl)
        return data
    }
    
    func authenticate(data: WWWAuthenticate) async throws -> String {
        var url = URLComponents(string: data.realm)!
        url.queryItems = [
            URLQueryItem(name: "service", value: data.service),
            URLQueryItem(name: "scope", value: data.scope)
            ]
        let (data, _) = try await urlSession.data(from: url.url!)
        let jsonDecoder = JSONDecoder()
        let token = try jsonDecoder.decode(AuthResponse.self, from: data)
        return token.token
    }
    
    
    func request(authentication: AuthenticationType, url: URL, headers: [String: String] = [:]) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        for (headerName, headerValue) in headers {
            request.setValue(headerValue, forHTTPHeaderField: headerName)
        }
        
        switch authentication {
        case let .basic(username, password):
            let credentials =  Data("\(username):\(password)".utf8).base64EncodedString()
            request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        case let .bearer(token):
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        case .none:
            break
        }
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResp = response as? HTTPURLResponse else {
            throw OCIError.generic
        }
        if httpResp.statusCode == 401 {
            guard let auth = WWWAuthenticate(response: httpResp) else { fatalError() }
            let token = try await authenticate(data: auth)
            return try await self.request(authentication: .bearer(token: token), url: url, headers: headers)
        }
        guard httpResp.statusCode == 200 else {
            throw OCIError.generic
        }
        return (data, httpResp)
    }
    
    func download(authentication: AuthenticationType, url: URL, headers: [String: String] = [:]) async throws -> (URLSession.AsyncBytes, HTTPURLResponse) {
        var request = URLRequest(url: url)
        for (headerName, headerValue) in headers {
            request.setValue(headerValue, forHTTPHeaderField: headerName)
        }
        if case let .bearer(token) = authentication {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await urlSession.bytes(for: request)
        guard let httpResp = response as? HTTPURLResponse else {
            fatalError() // not http
        }
        if httpResp.statusCode == 401 {
            guard let auth = WWWAuthenticate(response: httpResp) else { fatalError() }
            let token = try await authenticate(data: auth)
            return try await self.download(authentication: .bearer(token: token), url: url, headers: headers)
        }
        guard httpResp.statusCode == 200 else {
            throw OCIError.generic
        }
        return (data, httpResp)
    }
    
    public enum AuthenticationType {
        case none
        case basic(username: String, password: String)
        case bearer(token: String)
    }
}

struct AuthResponse: Decodable {
    let token: String
}


enum OCIError: Error {
    case generic
}
