import Foundation
import Yams

class ConfigManager {
    static let configPaths = ["/cilicon.yml", "/.cilicon.yml"]
        .map { NSHomeDirectory() + $0 }

    static var fileExists: Bool {
        configPaths.map(FileManager.default.fileExists).contains(true)
    }

    let config: Config

    init() throws {
        let decoder = YAMLDecoder()
        guard let data = Self.configPaths.compactMap(FileManager.default.contents).first else {
            throw ConfigManagerError.fileCouldNotBeRead
        }
        self.config = try decoder.decode(Config.self, from: data)
    }
}

enum ConfigManagerError: Error {
    case fileCouldNotBeRead
}
