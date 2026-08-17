import Foundation

enum LayerV1Downloader {
    static func pull(registry: OCI,
                     diskLayers: [Descriptor],
                     diskURL: URL,
                     progress: Progress,
                     progressStore: LayerProgressStore) async throws {
        let completedDigests = progressStore.loadCompletedDigests()

        // Layers are decompressed sequentially into a single continuous stream, so we can only
        // resume once we know how many layers, starting from the first one, already completed.
        var resumeOffset: UInt64 = 0
        var remainingLayers: [Descriptor] = []
        var reachedIncomplete = false
        for diskLayer in diskLayers {
            if !reachedIncomplete && completedDigests.contains(diskLayer.digest) {
                resumeOffset += try diskLayer.getDecompressedSize()
                progress.completedUnitCount += diskLayer.size
            } else {
                reachedIncomplete = true
                remainingLayers.append(diskLayer)
            }
        }

        guard !remainingLayers.isEmpty else { return }

        let decompressor = try Decompressor(fileURL: diskURL, initialOffset: resumeOffset)
        for diskLayer in remainingLayers {
            let data = try await registry.pullBlobData(digest: diskLayer.digest)
            try decompressor.decompress(data: data)
            progress.completedUnitCount += Int64(data.count)
            progressStore.markCompleted(diskLayer.digest)
        }
        try decompressor.finalize()
    }
}
