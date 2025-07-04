import XCTest

@testable import Cilicon

final class OCIURLTests: XCTestCase {
    // MARK: - init(string:)

    func test_initWithString_missingScheme_isNil() {
        XCTAssertNil(OCIURL(string: "example.com/namespace/image_name:tag"))
    }

    func test_initWithString_invalidScheme_isNil() {
        XCTAssertNil(OCIURL(string: "https://example.com/namespace/image_name:tag"))
    }

    func test_initWithString_missingPath_isNil() {
        XCTAssertNil(OCIURL(string: "oci://example.com:tag"))
    }

    func test_initWithString_missingTag_isNil() {
        XCTAssertNil(OCIURL(string: "oci://example.com/namespace/image_name"))
    }

    func test_initWithString_tag() throws {
        let sut = try XCTUnwrap(OCIURL(string: "oci://example.com/namespace/image_name:tag"))

        XCTAssertEqual(sut.scheme, "oci")
        XCTAssertEqual(sut.registry, "example.com")
        XCTAssertEqual(sut.repository, "/namespace/image_name")
        XCTAssertEqual(sut.tag, "tag")
    }

    // MARK: - encode()

    func test_encode() throws {
        let sut = try XCTUnwrap(OCIURL(string: "oci://example.com/namespace/image_name:tag"))

        let encodedData = try JSONEncoder().encode(sut)
        let encodedString = String(data: encodedData, encoding: .utf8)
        XCTAssertEqual(encodedString, #""oci:\/\/example.com\/namespace\/image_name:tag""#)
    }
}
