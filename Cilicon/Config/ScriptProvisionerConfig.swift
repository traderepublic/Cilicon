import Foundation

struct ScriptProvisionerConfig: Codable {
    /// The block to run
    let run: String
    
    init(run: String) {
        self.run = run
    }
}
