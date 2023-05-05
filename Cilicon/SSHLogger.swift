import Foundation

@MainActor
final class SSHLogger: ObservableObject {
    static let shared = SSHLogger()

    private init() { }

    @Published
    var log: [LogChunk] = []

    func log(string: String) {
        /// Skip empty logs
        guard string.isNotBlank else { return }
        let text = ANSIParser.parse(string)
        let chunk = LogChunk(text: text)
        log.append(chunk)
    }

    struct LogChunk: Identifiable, Hashable {
        let id = UUID()
        let text: AttributedString
    }
}

extension String {
    var isBlank: Bool {
        allSatisfy(\.isWhitespace)
    }

    var isNotBlank: Bool {
        isBlank == false
    }
}
