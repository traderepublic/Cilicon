import Foundation
import NIOCore

@Observable
final class SSHLogger {
    var log: [LogChunk] = []

    var attributedLog: AttributedString {
        return ANSIParser.parse(combinedLog)
    }

    var combinedLog: String {
        var outString = String()
        for item in log {
            outString.append(item.text)
            outString.append("\n")
        }
        return outString
    }

    func log(buffer: ByteBuffer) {
        log(string: String(buffer: buffer))
    }

    func log(string: String) {
        /// Skip empty logs
        guard string.isNotBlank else { return }
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
