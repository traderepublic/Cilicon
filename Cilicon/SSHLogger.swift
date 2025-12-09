import Foundation

@MainActor
final class SSHLogger: ObservableObject {
    static let shared = SSHLogger()

    private static let maxLogChunks = 500
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()

    private init() { }

    @Published
    var log: [LogChunk] = []

    var attributedLog: AttributedString {
        return ANSIParser.parse(combinedLog)
    }

    var combinedLog: String {
        var outString = String()
        for item in log {
            outString.append("[\(Self.dateFormatter.string(from: item.timestamp))] \(item.text)\n")
        }
        return outString
    }

    func log(string: String) {
        let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedString.isEmpty else { return }

        let lines = trimmedString.split(separator: "\n", omittingEmptySubsequences: false)
        for line in lines {
            log.append(LogChunk(text: String(line)))
        }
        if log.count > Self.maxLogChunks {
            log.removeLast(log.count - Self.maxLogChunks)
        }
    }

    struct LogChunk: Identifiable, Hashable {
        let id = UUID()
        let timestamp = Date()
        var text: String
    }
}
