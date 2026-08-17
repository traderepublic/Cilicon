import Foundation

public struct OCI: Sendable {
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
        return try (contentDigest, jsonDecoder.decode(Manifest.self, from: data))
    }

    public func pullBlobData(digest: String, authentication: AuthenticationType = .none) async throws -> Data {
        let blobUrl = baseURL.appending(path: "blobs/\(digest)")
        let resumeDataURL = Self.resumeDataFileURL(forDigest: digest)
        var resumeData = try? Data(contentsOf: resumeDataURL)
        var lastError: Error = OCIError.generic

        for attempt in 0..<Self.maxDownloadAttempts {
            do {
                let (data, _) = try await download(authentication: authentication, url: blobUrl, resumeData: resumeData)
                try? FileManager.default.removeItem(at: resumeDataURL)
                return data
            } catch let error as ResumableDownloadError {
                resumeData = error.resumeData
                if let resumeData {
                    try? FileManager.default.createDirectory(
                        at: resumeDataURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    try? resumeData.write(to: resumeDataURL)
                } else {
                    try? FileManager.default.removeItem(at: resumeDataURL)
                }
                lastError = error.underlying
            } catch {
                if error is CancellationError { throw error }
                resumeData = nil
                try? FileManager.default.removeItem(at: resumeDataURL)
                lastError = error
            }

            if attempt < Self.maxDownloadAttempts - 1 {
                let backoffSeconds = Int(min(pow(2.0, Double(attempt + 1)), 30))
                try await Task.sleep(for: .seconds(backoffSeconds))
            }
        }
        throw lastError
    }

    private static let maxDownloadAttempts = 8

    private static func resumeDataFileURL(forDigest digest: String) -> URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: "Cilicon/ResumeData")
        let safeName = digest.replacingOccurrences(of: ":", with: "_").replacingOccurrences(of: "/", with: "_")
        return cacheDir.appending(path: "\(safeName).resumedata")
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
            let credentials = Data("\(username):\(password)".utf8).base64EncodedString()
            request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        case let .bearer(token):
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        case .none:
            break
        }

        let (data, response) = try await dataWithRetry(for: request)
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

    func download(
        authentication: AuthenticationType,
        url: URL,
        headers: [String: String] = [:],
        resumeData: Data? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        let fileURL: URL
        let response: URLResponse
        do {
            if let resumeData {
                // resumeData is self-contained (original request, headers and validators),
                // so it's reissued as-is rather than rebuilding the request.
                (fileURL, response) = try await urlSession.download(resumeFrom: resumeData)
            } else {
                var request = URLRequest(url: url)
                for (headerName, headerValue) in headers {
                    request.setValue(headerValue, forHTTPHeaderField: headerName)
                }
                if case let .bearer(token) = authentication {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                (fileURL, response) = try await urlSession.download(for: request)
            }
        } catch {
            if error is CancellationError { throw error }
            let recoveredResumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data
            throw ResumableDownloadError(underlying: error, resumeData: recoveredResumeData)
        }

        let data = try Data(contentsOf: fileURL, options: .alwaysMapped)
        try FileManager.default.removeItem(at: fileURL)

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

    /// Retries small, non-resumable requests (e.g. manifest fetches) from scratch on transient
    /// network errors, since there's no meaningful partial state to preserve for these.
    private func dataWithRetry(for request: URLRequest, maxAttempts: Int = 4) async throws -> (Data, URLResponse) {
        var lastError: Error = OCIError.generic
        for attempt in 0..<maxAttempts {
            do {
                return try await urlSession.data(for: request)
            } catch {
                if error is CancellationError { throw error }
                lastError = error
                if attempt < maxAttempts - 1 {
                    let backoffSeconds = Int(min(pow(2.0, Double(attempt + 1)), 30))
                    try await Task.sleep(for: .seconds(backoffSeconds))
                }
            }
        }
        throw lastError
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

struct ResumableDownloadError: Error {
    let underlying: Error
    let resumeData: Data?
}
