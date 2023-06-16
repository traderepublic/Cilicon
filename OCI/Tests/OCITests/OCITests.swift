@testable import OCI
import Compression
import XCTest

final class OCITests: XCTestCase {
    func testExample() async throws {
        let url = OCIURL(string: "oci://ghcr.io/cirruslabs/macos-ventura-xcode:14.2")!
        let ociClient = OCI(url: url)

        let (_, manifest) = try await ociClient.fetchManifest()
        let totalSize = manifest.layers.map(\.size).reduce(into: Int64(0), +=)

        let bufferSizeBytes = 64 * 1024 * 1024

        let diskURL = URL(string: NSString("~/disk.img").expandingTildeInPath)!
        FileManager.default.createFile(atPath: diskURL.path, contents: nil)

        let disk = try FileHandle(forWritingTo: diskURL)
        let filter = try OutputFilter(.decompress, using: .lz4, bufferCapacity: bufferSizeBytes) { data in
            if let data {
                disk.write(data)
            }
        }

        let imgLayers = manifest.layers.filter { $0.mediaType == "application/vnd.cirruslabs.tart.disk.v1" }
        var lastDataCount = 0
        var lastProgress: Double = -1
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 2

        for (index, layer) in imgLayers.enumerated() {
            print("Downloading disk image layer \(index + 1)/\(imgLayers.count)")
            var data = Data()
            data.reserveCapacity(Int(layer.size))
            for try await byte in try await ociClient.pullBlob(digest: layer.digest) {
                data.append(byte)
                let progress = Double(data.count + lastDataCount) / Double(totalSize)
                if progress - lastProgress > 0.001 {
                    lastProgress = progress
                    print(formatter.string(from: NSNumber(value: progress))!)
                }
            }
            lastDataCount += data.count
            try filter.write(data)
        }
        try filter.finalize()
    }
}
