import Compression
import Foundation
import OCI

class LayerV2Downloader: Downloader {
    static func pull(registry: OCI,
                     diskLayers: [Descriptor],
                     diskURL: URL,
                     maxConcurrency: UInt,
                     progress: Progress) async throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: diskURL.path) {
            try fm.removeItem(at: diskURL)
        }
        if !FileManager.default.createFile(atPath: diskURL.path, contents: nil) {
            fatalError("failed to create file at path \(diskURL.path)")
        }
        var uncompressedDiskSize: UInt64 = 0

        for layer in diskLayers {
            guard let uncompressedLayerSize = layer.uncompressedSize else {
                fatalError()
            }
            uncompressedDiskSize += uncompressedLayerSize
        }
        let disk = try FileHandle(forWritingTo: diskURL)
        // reserve the space for the uncompressed disk
        try disk.truncate(atOffset: uncompressedDiskSize)
        try disk.close()

        try await withThrowingTaskGroup(of: Void.self) { taskGroup in
            var totalDiskOffset: UInt64 = 0

            for (index, diskLayer) in diskLayers.enumerated() {
                // Start queueing once we reach the max concurrency
                if index >= maxConcurrency {
                    try await taskGroup.next()
                }

                guard let uncompressedLayerSize = diskLayer.uncompressedSize else {
                    fatalError("V2 Layer must have an uncompressed size")
                }

                let layerDiskOffset = totalDiskOffset
                taskGroup.addTask {
                    let disk = try FileHandle(forWritingTo: diskURL)
                    try disk.seek(toOffset: layerDiskOffset)
                    let filter = try OutputFilter(
                        .decompress,
                        using: .lz4,
                        bufferCapacity: Self.filterBufferSize
                    ) {
                        if let decompressedData = $0 {
                            disk.write(decompressedData)
                        }
                    }

                    let data = try await registry.pullBlobData(digest: diskLayer.digest)
                    try filter.write(data)
                    progress.completedUnitCount += Int64(data.count)
                    try disk.close()
                }
                totalDiskOffset += uncompressedLayerSize
            }
        }
    }
}
