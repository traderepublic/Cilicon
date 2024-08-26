extension Descriptor {
    func getDecompressedSize() throws -> UInt64 {
        guard let size = annotations?["org.cirruslabs.tart.uncompressed-size"] else {
            throw DescriptorError.decompressedSizeMissing
        }
        return try UInt64(value: size)
    }
}

extension [Descriptor] {
    func getTotalDecompressedSize() throws -> UInt64 {
        try reduce(0) {
            guard let size = $1.annotations?["org.cirruslabs.tart.uncompressed-size"] else {
                return $0
            }
            return try $0 + UInt64(value: size)
        }
    }
}

enum DescriptorError: Error {
    case decompressedSizeMissing
}
