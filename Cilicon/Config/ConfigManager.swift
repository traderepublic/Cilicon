import Foundation
import Yams

class ConfigManager {
    static let path = NSHomeDirectory() + "/cilicon.yml"
    static var fileExists: Bool {
        FileManager.default.fileExists(atPath: path)
    }

    let config: Config

    init() throws {
        let decoder = YAMLDecoder()
        guard let data = FileManager.default.contents(atPath: Self.path) else {
            throw ConfigManagerError.fileCouldNotBeRead
        }
        self.config = try decoder.decode(Config.self, from: data)
    }
}

enum ConfigManagerError: Error {
    case fileCouldNotBeRead
}
