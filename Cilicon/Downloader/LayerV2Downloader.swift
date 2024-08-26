import Foundation
import Semaphore

enum LayerV2Downloader {
    static func pull(registry: OCI,
                     diskLayers: [Descriptor],
                     diskURL: URL,
                     progress: Progress,
                     maxConcurrency: Int = 4) async throws {
        let semaphore = AsyncSemaphore(value: maxConcurrency)
        // Reserve file size
        let totDecompressedSize = try diskLayers.getTotalDecompressedSize()
        let disk = try FileHandle(forWritingTo: diskURL)
        try disk.truncate(atOffset: totDecompressedSize)
        try disk.close()

        try await withThrowingTaskGroup(of: Void.self) { taskGroup in
            var totalDiskOffset: UInt64 = 0
            for diskLayer in diskLayers {
                await semaphore.wait()
                let layerDiskOffset = totalDiskOffset
                taskGroup.addTask {
                    let decomp = try Decompressor(fileURL: diskURL)
                    let data = try await registry.pullBlobData(digest: diskLayer.digest)
                    try decomp.decompress(data: data, offset: layerDiskOffset)
                    try decomp.finalize()
                    progress.completedUnitCount += Int64(data.count)
                    semaphore.signal()
                }
                totalDiskOffset += try diskLayer.getDecompressedSize()
            }
        }
    }
}
