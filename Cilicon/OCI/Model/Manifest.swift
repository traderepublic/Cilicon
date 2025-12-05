import Foundation

public struct Manifest: Decodable, Sendable {
    public let schemaVersion: Int
    public let mediaType: String
    public let artifactType: String?
    public let config: Config
    public let layers: [Descriptor]
    public let subject: Descriptor?
    public let annotations: [String: String]?

    public struct Config: Decodable, Sendable {
        public let mediaType: String
    }
}
