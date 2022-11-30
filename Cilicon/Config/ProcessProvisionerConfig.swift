import Foundation

struct ProcessProvisionerConfig: Decodable {
    /// The executable to be run
    let executablePath: String
    /// The arguments to be passed to the executable. These will be appended to the bundle path and action arguments.
    let arguments: [String]
    
    enum CodingKeys: CodingKey {
        case executablePath
        case arguments
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.executablePath = try container.decode(String.self, forKey: .executablePath)
        self.arguments = try container.decodeIfPresent([String].self, forKey: .arguments) ?? []
    }
}
