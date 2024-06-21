import Foundation

enum LayerV1Downloader {
    static func pull(registry: OCI,
                     diskLayers: [Descriptor],
                     diskURL: URL,
                     progress: Progress) async throws {
        let decompressor = try Decompressor(fileURL: diskURL)
        for diskLayer in diskLayers {
            let data = try await registry.pullBlobData(digest: diskLayer.digest)
            try decompressor.decompress(data: data)
            progress.completedUnitCount += Int64(data.count)
        }
        try decompressor.finalize()
    }
}
