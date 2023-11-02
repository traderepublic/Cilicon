import Foundation
import os.log

@MainActor
final class SSHLogger: ObservableObject {
    static let shared = SSHLogger()

    private let osLogger = Logger(category: "SSH")

    private init() { }

    @Published
    var log: [LogChunk] = []

    var attributedLog: AttributedString {
        return ANSIParser.parse(combinedLog)
    }

    var combinedLog: String {
        var outString = String()
        log.forEach {
            outString.append($0.text)
            outString.append("\n")
        }
        return outString
    }

    func log(string: String) {
        /// Skip empty logs
        guard string.isNotBlank else { return }

        osLogger.notice("\(ANSIParser.stripped(string), privacy: .public)")

        if log.isEmpty {
            log = [LogChunk(text: string)]
            return
        }
        let lines = string.split(separator: "\n", omittingEmptySubsequences: false)
        for (index, line) in lines.enumerated() {
            if index == 0 {
                log[log.count - 1].text.append(contentsOf: line)
            } else {
                if log.count >= 500 {
                    log.remove(at: 0)
                }
                log.append(LogChunk(text: String(line)))
            }
        }
    }

    struct LogChunk: Identifiable, Hashable {
        let id = UUID()
        var text: String
        var attributedText: AttributedString {
            return ANSIParser.parse(text)
        }
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
