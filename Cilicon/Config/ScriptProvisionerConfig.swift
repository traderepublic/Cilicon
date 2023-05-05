import Foundation

struct ScriptProvisionerConfig: Decodable {
    /// The block to run
    let run: String
    
    enum CodingKeys: CodingKey {
        case run
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.run = try container.decode(String.self, forKey: .run)
    }
}
