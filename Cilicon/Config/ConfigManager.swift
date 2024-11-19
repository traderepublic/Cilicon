import Foundation
import Yams

class ConfigManager {
    let config: Config

    /// Default config
    static let fallbackConfigPath = ["/cilicon.yml", "/.cilicon.yml"]
        .map { NSHomeDirectory() + $0 }
        .filter(FileManager.default.fileExists).first

    init() throws {
        let decoder = YAMLDecoder()

        // Launch argument to config e.g. ~/cilicon.yml
        // If no launch argument is found. The default fallback config is used
        guard let configPath = UserDefaults.standard.string(forKey: "config-path") ?? Self.fallbackConfigPath,
              FileManager.default.fileExists(atPath: configPath) else {
            throw ConfigManagerError.fileDoesNotExist
        }
        guard let data = FileManager.default.contents(atPath: configPath) else {
            throw ConfigManagerError.fileCouldNotBeRead
        }
        self.config = try decoder.decode(Config.self, from: data)
    }
}

enum ConfigManagerError: Error {
    case fileCouldNotBeRead
    case fileDoesNotExist
}
