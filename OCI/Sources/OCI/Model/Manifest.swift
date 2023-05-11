import Foundation

public struct Manifest: Decodable {
    public let schemaVersion: Int
    public let mediaType: String
    public let artifactType: String?
    public let config: Config
    public let layers: [Descriptor]
    public let subject: Descriptor?
    public let annotations: [String: String]?
    
    public struct Config: Decodable {
        public let mediaType: String
    }
}
