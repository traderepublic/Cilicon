import Compression
import Foundation
import OCI

class LayerV2Downloader: Downloader {
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
        // Calculate the uncompressed disk size
        var uncompressedDiskSize: UInt64 = 0

        for layer in diskLayers {
            guard let uncompressedLayerSize = layer.uncompressedSize else {
                fatalError()
            }

            uncompressedDiskSize += uncompressedLayerSize
        }

        let disk = try FileHandle(forWritingTo: diskURL)
        try disk.truncate(atOffset: uncompressedDiskSize)
        try disk.close()

        try await withThrowingTaskGroup(of: Void.self) { group in
            var globalDiskWritingOffset: UInt64 = 0

            for (index, diskLayer) in diskLayers.enumerated() {
                // Queue if we are already at the concurrency limit
                if index >= concurrency {
                    try await group.next()
                }

                guard let uncompressedLayerSize = diskLayer.uncompressedSize else {
                    fatalError("V2 Layer must have an uncompressed size")
                }

                let diskWritingOffset = globalDiskWritingOffset
                group.addTask {
                    let disk = try FileHandle(forWritingTo: diskURL)
                    try disk.seek(toOffset: diskWritingOffset)
                    let filter = try OutputFilter(.decompress, using: .lz4, bufferCapacity: Self.bufferSizeBytes) { data in
                        if let data {
                            disk.write(data)
                        }
                    }

                    let data = try await registry.pullBlobData(digest: diskLayer.digest)
                    progress.completedUnitCount += Int64(data.count)
                    try filter.write(data)
                    try disk.close()
                }

                globalDiskWritingOffset += uncompressedLayerSize
            }
        }
    }
}
