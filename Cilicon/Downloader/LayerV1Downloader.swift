import Compression
import Foundation
import OCI

class LayerV1Downloader: Downloader {
    static func pull(registry: OCI,
                     diskLayers: [Descriptor],
                     diskURL: URL,
                     progress: Progress) async throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: diskURL.path) {
            try fm.removeItem(at: diskURL)
        }
        if !fm.createFile(atPath: diskURL.path, contents: nil) {
            fatalError("failed to create file at path \(diskURL.path)")
        }
        let diskFileHandle = try FileHandle(forWritingTo: diskURL)

        let filter = try OutputFilter(
            .decompress,
            using: .lz4,
            bufferCapacity: Self.filterBufferSize
        ) {
            if let decompressedData = $0 {
                diskFileHandle.write(decompressedData)
            }
        }

        for diskLayer in diskLayers {
            let data = try await registry.pullBlobData(digest: diskLayer.digest)
            progress.completedUnitCount += Int64(data.count)
            try filter.write(data)
        }

        try filter.finalize()
        try diskFileHandle.close()
    }
}
