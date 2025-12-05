import Foundation

public struct Descriptor: Decodable, Sendable {
    public let mediaType: String
    public let digest: String
    public let size: Int64
    public let urls: [URL]?
    public let annotations: [String: String]?
    public let data: String?
    public let artifactType: String?
}
