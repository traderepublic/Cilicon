import Foundation
import OCI

enum LayerV2Downloader {
    static func pull(registry: OCI,
                     diskLayers: [Descriptor],
                     diskURL: URL,
                     progress: Progress,
                     maxConcurrency: Int) async throws {
        // Reserve file size
        let totDecompressedSize = try diskLayers.getTotalDecompressedSize()
        let disk = try FileHandle(forWritingTo: diskURL)
        try disk.truncate(atOffset: totDecompressedSize)
        try disk.close()

        try await withThrowingTaskGroup(of: Void.self) { taskGroup in
            var totalDiskOffset: UInt64 = 0
            for (index, diskLayer) in diskLayers.enumerated() {
                if index >= maxConcurrency {
                    try await taskGroup.next()
                }
                let layerDiskOffset = totalDiskOffset
                taskGroup.addTask {
                    let decomp = try Decompressor(fileURL: diskURL)
                    let data = try await registry.pullBlobData(digest: diskLayer.digest)
                    try decomp.decompress(data: data, offset: layerDiskOffset)
                    try decomp.finalize()
                    progress.completedUnitCount += Int64(data.count)
                }
                totalDiskOffset += try diskLayer.getDecompressedSize()
            }
        }
    }
}
