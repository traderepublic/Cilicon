import Foundation
public struct OCI {
    
    static let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = false
        return URLSession(configuration: config)
    }()
    
    public static func fetchManifest(authentication: AuthenticationType = .none) async throws -> Manifest {
        
        
        let manifestURL = URL(string: "https://ghcr.io/v2/cirruslabs/macos-ventura-xcode/manifests/14.2")!
        
        var urlRequest = URLRequest(url: manifestURL)
        switch authentication {
        case let .bearer(token):
            print(token)
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            urlRequest.setValue("Accept", forHTTPHeaderField: "application/vnd.oci.image.manifest.v1+json")
        default:
            break
        }
        
        let (data, response) = try await urlSession.data(for: urlRequest)
        print(data)
        guard let httpResp = response as? HTTPURLResponse else {
            fatalError() // not http
        }
        if httpResp.statusCode == 401 {
            guard let authenticateHeader = httpResp.value(forHTTPHeaderField: "www-authenticate"), let auth = WWWAuthenticate(string: authenticateHeader) else { fatalError() }
            let token = try await authenticate(data: auth)
            return try await fetchManifest(authentication: .bearer(token: token))
        }
        guard httpResp.statusCode == 200 else {
            fatalError()
        }
        
        let jsonDecoder = JSONDecoder()
        return try jsonDecoder.decode(Manifest.self, from: data)
    }
    
    static func authenticate(data: WWWAuthenticate) async throws -> String {
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
    
    
    public enum AuthenticationType {
        case none
        case basic(username: String, password: String)
        case bearer(token: String)
    }
}

struct WWWAuthenticate {
    let authMode: String
    let realm: String
    let service: String
    let scope: String
    init?(string: String) {
        
        let components = string
            .trimmingCharacters(in: .whitespaces)
            .split(separator: " ", maxSplits: 1)
            
        guard components.count == 2 else { return nil }
        self.authMode = String(components[0])
        let items = components[1].split(separator: ",")
        let dictionary = items.reduce(into: [String: String]()) {
            let keyVal = $1.split(separator: "=", maxSplits: 1)
            $0[String(keyVal[0])] = String(keyVal[1]).replacingOccurrences(of: "\"", with: "")
        }
        
        guard let realm = dictionary["realm"],
              let service = dictionary["service"],
              let scope = dictionary["scope"] else { return nil }
        self.realm = realm
        self.service = service
        self.scope = scope
    }
}


struct AuthResponse: Decodable {
    let token: String
}
