import XCTest
@testable import OCI

final class OCITests: XCTestCase {
    func testExample() async throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        try await OCI.fetchManifest()
    }
}
