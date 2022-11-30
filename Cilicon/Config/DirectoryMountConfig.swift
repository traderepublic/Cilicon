import Foundation

struct DirectoryMountConfig: Decodable {
    /// The path of the folder to be mounted in the Guest OS.
    let hostPath: String
    /// The folder name in /Volumes/My Shared Files/ that the directory should be mounted to.
    let guestFolder: String
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.hostPath = (try container.decode(String.self, forKey: .hostPath) as NSString).standardizingPath
        self.guestFolder = try container.decode(String.self, forKey: .guestFolder)
    }
    
    enum CodingKeys: CodingKey {
        case hostPath
        case guestFolder
    }
}
