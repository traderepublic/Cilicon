import Foundation

final class SSHLogger: ObservableObject {
    static let shared = SSHLogger()
    
    private init() {}
    
    @Published
    var log: [LogChunk] = []
    
    
    func log(string: String) {
        let chunk = LogChunk(text: string)
        log.append(chunk)
    }
    
    struct LogChunk: Identifiable, Hashable {
        let id = UUID()
        let text: String
    }
}



