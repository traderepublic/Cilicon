import Foundation
import OCI

protocol Downloader {
    static func pull(registry: OCI, diskLayers: [Descriptor], diskURL: URL, concurrency: UInt, progress: Progress) async throws
}
