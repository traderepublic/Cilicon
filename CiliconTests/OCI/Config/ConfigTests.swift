import XCTest
import Yams

@testable import Cilicon

final class ConfigTests: XCTestCase {
    private var yamlDecoder: YAMLDecoder!

    override func setUp() {
        yamlDecoder = YAMLDecoder()
    }

    override func tearDown() {
        yamlDecoder = nil
    }

    func test_decode_consoleDevices_notPresent_isEmptyArray() throws {
        let yaml = fixtureConfig
        let sut = try yamlDecoder.decode(Config.self, from: Data(yaml.utf8))

        XCTAssertEqual(sut.consoleDevices, [])
    }

    func test_decode_consoleDevices_isPresent_isParsedCorrectly() throws {
        let yaml = fixtureConfig.appending("""
        consoleDevices:
          - test-device
          - test-device2
        """)

        let sut = try yamlDecoder.decode(Config.self, from: Data(yaml.utf8))
        XCTAssertEqual(sut.consoleDevices, ["test-device", "test-device2"])
    }
}

private extension ConfigTests {
    var fixtureConfig: String {
        """
        source: oci://example.com/namespace/image_name:tag
        provisioner:
          type: github
          config:
            appId: 123456
            organization: test-organization
            runnerGroup: test-group
            privateKeyPath: ~/github.pem

        """
    }
}
