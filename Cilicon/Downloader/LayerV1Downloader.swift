import Compression
import Foundation
import OCI

class LayerV1Downloader: Downloader {
    private static let bufferSizeBytes = 4 * 1024 * 1024
    private static let layerLimitBytes = 500 * 1000 * 1000

    static func pull(registry: OCI,
                     diskLayers: [Descriptor],
                     diskURL: URL,
                     concurrency: UInt,
                     progress: Progress) async throws {
        if !FileManager.default.createFile(atPath: diskURL.path, contents: nil) {
            fatalError()
        }

        // Open the disk file
        let disk = try FileHandle(forWritingTo: diskURL)

        // Decompress the layers onto the disk in a single stream
        let filter = try OutputFilter(.decompress, using: .lz4, bufferCapacity: Self.bufferSizeBytes) { data in
            if let data {
                disk.write(data)
            }
        }

        for diskLayer in diskLayers {
            let data = try await registry.pullBlobData(digest: diskLayer.digest)
            progress.completedUnitCount += Int64(data.count)
            try filter.write(data)
        }

        try filter.finalize()
        try disk.close()
    }
}
