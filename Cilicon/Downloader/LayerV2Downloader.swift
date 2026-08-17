import Foundation

enum LayerV2Downloader {
    static func pull(registry: OCI,
                     diskLayers: [Descriptor],
                     diskURL: URL,
                     progress: Progress,
                     maxConcurrency: Int,
                     progressStore: LayerProgressStore) async throws {
        // Reserve file size. Truncating to the same size again on a resumed download
        // is a no-op and doesn't discard the bytes already written by a previous attempt.
        let totDecompressedSize = try diskLayers.getTotalDecompressedSize()
        let disk = try FileHandle(forWritingTo: diskURL)
        try disk.truncate(atOffset: totDecompressedSize)
        try disk.close()

        let completedDigests = progressStore.loadCompletedDigests()

        // A plain (non-throwing) task group is used so that one layer exhausting its retries
        // doesn't cancel the other layers still downloading concurrently. Each child task
        // reports success/failure instead of throwing, and the first failure (if any) is
        // only surfaced once every layer has had a chance to finish.
        let firstError: Error? = await withTaskGroup(of: Result<Void, Error>.self) { taskGroup in
            var totalDiskOffset: UInt64 = 0
            var tasksAdded = 0
            var firstError: Error?

            for diskLayer in diskLayers {
                let layerDiskOffset = totalDiskOffset
                let layerDecompressedSize: UInt64
                do {
                    layerDecompressedSize = try diskLayer.getDecompressedSize()
                } catch {
                    firstError = firstError ?? error
                    continue
                }
                totalDiskOffset += layerDecompressedSize

                if completedDigests.contains(diskLayer.digest) {
                    progress.completedUnitCount += diskLayer.size
                    continue
                }

                if tasksAdded >= maxConcurrency, let result = await taskGroup.next() {
                    if case let .failure(error) = result {
                        firstError = firstError ?? error
                    }
                }
                tasksAdded += 1
                taskGroup.addTask {
                    do {
                        let decomp = try Decompressor(fileURL: diskURL)
                        let data = try await registry.pullBlobData(digest: diskLayer.digest)
                        try decomp.decompress(data: data, offset: layerDiskOffset)
                        try decomp.finalize()
                        progress.completedUnitCount += Int64(data.count)
                        progressStore.markCompleted(diskLayer.digest)
                        return .success(())
                    } catch {
                        return .failure(error)
                    }
                }
            }

            for await result in taskGroup {
                if case let .failure(error) = result {
                    firstError = firstError ?? error
                }
            }
            return firstError
        }

        if let firstError {
            throw firstError
        }
    }
}
