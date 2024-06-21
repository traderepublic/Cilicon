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
        try reduce(0) { try $0 + $1.getDecompressedSize() }
    }
}

enum DescriptorError: Error {
    case decompressedSizeMissing
}
