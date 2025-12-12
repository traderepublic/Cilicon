@testable import Cilicon
import XCTest

@MainActor
final class SSHLoggerTests: XCTestCase {
    private var sut: SSHLogger!

    override func setUp() async throws {
        sut = SSHLogger()
    }

    override func tearDown() async throws {
        sut = nil
    }

    func test_log_trimsWhitespaceAndStoresLine() {
        // When
        sut.log(string: "   hello world  \n")

        // Then
        XCTAssertEqual(sut.log.map(\.text), ["hello world"])
    }

    func test_log_ignoresEmptyOrWhitespaceOnlyInput() {
        // When
        sut.log(string: "   \n\t  ")

        // Then
        XCTAssertTrue(sut.log.isEmpty)
    }

    func test_log_splitsOnNewlines_preservingEmptyLines() {
        // When
        sut.log(string: "line1\n\nline3\n")

        // Then
        XCTAssertEqual(sut.log.map(\.text), ["line1", "", "line3"])
    }

    func test_log_respectsMaxLogChunksAndDropsOldestEntries() {
        // When Log more than the max number of chunks
        let maxLimit = SSHLogger.maxLogChunks
        let overLimit = maxLimit + 10
        for i in 0 ..< overLimit {
            sut.log(string: "line_\(i)")
        }

        // Then Oldest entries should be dropped; keep the most recent SSHLogger.maxLogChunks.
        XCTAssertEqual(sut.log.count, maxLimit)
        let firstKeptIndex = overLimit - maxLimit
        XCTAssertEqual(sut.log.first?.text, "line_\(firstKeptIndex)")
        XCTAssertEqual(sut.log.last?.text, "line_\(overLimit - 1)")
    }

    func test_log_timestampsAreNonDecreasing() {
        // When
        sut.log(string: "first")
        sut.log(string: "second")

        // Then
        XCTAssertEqual(sut.log.count, 2)
        let firstTimestamp = sut.log[0].timestamp
        let secondTimestamp = sut.log[1].timestamp
        XCTAssertLessThanOrEqual(firstTimestamp, secondTimestamp)
    }
}
