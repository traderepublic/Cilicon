import Foundation
import OCI

protocol Downloader {
    static func pull(registry: OCI, diskLayers: [Descriptor], diskURL: URL, maxConcurrency: UInt, progress: Progress) async throws
}

extension Downloader {
    static var filterBufferSize: Int { 4 * 1024 * 1024 }
}
