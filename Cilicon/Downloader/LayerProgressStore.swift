import Foundation

/// Tracks which manifest layers have already been fully downloaded and written to disk,
/// so a retry after a connection failure can skip them instead of starting the whole
/// image download over again.
struct LayerProgressStore {
    let fileURL: URL

    func loadCompletedDigests() -> Set<String> {
        guard let data = try? Data(contentsOf: fileURL),
              let digests = try? JSONDecoder().decode(Set<String>.self, from: data) else {
            return []
        }
        return digests
    }

    func markCompleted(_ digest: String) {
        var digests = loadCompletedDigests()
        digests.insert(digest)
        if let data = try? JSONEncoder().encode(digests) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func reset() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
