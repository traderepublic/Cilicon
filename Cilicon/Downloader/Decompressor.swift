import Compression
import Foundation

class Decompressor {
    static var filterBufferSize: Int { 4 * 1024 * 1024 }
    let disk: FileHandle
    let filter: OutputFilter

    init(fileURL: URL, initialOffset: UInt64 = 0) throws {
        let disk = try FileHandle(forWritingTo: fileURL)
        if initialOffset > 0 {
            try disk.seek(toOffset: initialOffset)
        }
        self.disk = disk
        self.filter = try OutputFilter(
            .decompress,
            using: .lz4,
            bufferCapacity: Self.filterBufferSize
        ) {
            if let decompressedData = $0 {
                disk.write(decompressedData)
            }
        }
    }

    func decompress(data: Data, offset: UInt64? = nil) throws {
        if let offset {
            try disk.seek(toOffset: offset)
        }
        try filter.write(data)
    }

    func finalize() throws {
        try filter.finalize()
        try disk.close()
    }
}
