import Foundation

public struct OCIURL: Encodable {
    public let scheme: String
    public let registry: String
    public let repository: String
    public let tag: String

    public init?(urlComponents: URLComponents) {
        guard let scheme = urlComponents.scheme,
              scheme == "oci",
              let host = urlComponents.host,
              let path = urlComponents.path.removingPercentEncoding,
              !path.isEmpty
        else {
            return nil
        }

        let components = path.split(separator: ":")
        guard components.count >= 2 else {
            return nil
        }
        self.scheme = scheme
        self.registry = host
        // Assume the first component is the repository and the rest is the tag.
        self.repository = String(components[0])
        self.tag = components.dropFirst().joined(separator: ":")
    }

    public init?(string: String) {
        guard let components = URLComponents(string: string) else { return nil }
        self.init(urlComponents: components)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode("\(scheme)://\(registry)\(repository):\(tag)")
    }
}
