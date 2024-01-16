import OCI

extension Descriptor {
    var uncompressedSize: UInt64? {
        guard let size = annotations?["org.cirruslabs.tart.uncompressed-size"] else {
            return nil
        }

        return UInt64(size)
    }

    var uncompressedContentDigest: String? {
        annotations?["org.cirruslabs.tart.uncompressed-content-digest"]
    }
}
