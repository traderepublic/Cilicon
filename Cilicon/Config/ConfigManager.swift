import Foundation
import Yams

class ConfigManager {
    let config: Config
    
    init() throws {
        let decoder = YAMLDecoder()
        guard let data = FileManager.default.contents(atPath: NSHomeDirectory() + "/cilicon.yml") else {
            throw ConfigManagerError.fileCouldNotBeRead
        }
        self.config = try decoder.decode(Config.self, from: data)
    }
    
}

enum ConfigManagerError: Error {
    case fileCouldNotBeRead
}
