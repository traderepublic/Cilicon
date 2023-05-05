import AppKit

struct ANSIParser {
    typealias Color = NSColor
    typealias Font = NSFont

    static func parse(_ log: String) -> AttributedString {
        let regex = try? NSRegularExpression(pattern: "\\[[0-9;]+m", options: [])
        let range = NSMakeRange(0, log.count)
        let result = NSMutableAttributedString()
        var ranges: [NSRange] = []

        regex?.enumerateMatches(in: log, options: [], range: range) { match, _, _ in
            guard let match else { return }
            ranges.append(match.range)
        }

        /// Used to have a pair (current, next) of the same array
        var nextRanges = ranges.dropFirst()
        nextRanges.append(NSMakeRange(log.count, 0))

        /// Looping over (current, next), in the middle will be the `text` to attribute
        for (this, next) in zip(ranges, nextRanges) {
            let thisStartIndex = log.index(log.startIndex, offsetBy: this.location)
            let thisEndIndex = log.index(log.startIndex, offsetBy: this.location + this.length)
            let nextStartIndex = log.index(log.startIndex, offsetBy: next.location)
            let ansiCode = log[thisStartIndex ..< thisEndIndex]
            let attributedString = NSMutableAttributedString(
                string: String(log[thisEndIndex ..< nextStartIndex]),
                attributes: attributesFor(ansiCode: String(ansiCode))
            )
            result.append(attributedString)
        }

        /// Fallback in case failed to parse
        if result.string.isEmpty {
            result.append(.init(string: log))
        }

        return AttributedString(result)
    }

    private static func attributesFor(ansiCode: String) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [:]
        let codes = ansiCode
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .decimalDigits.inverted) }
            .map { Int($0) ?? 0 }

        /// In case of `38` and `48` -> `break codesLoop` as final part of attribute format
        codesLoop: for (index, code) in codes.enumerated() {
            switch code {
            case 0: attributes = [:]
            case 1: attributes[.font] = Font.boldSystemFont(ofSize: Font.systemFontSize)
            case 3: attributes[.font] = Font.italicSystemFont(ofSize: Font.systemFontSize)
            case 4: attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            case 9: attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            case 30 ... 37: attributes[.foregroundColor] = colorFromAnsiCode(code - 30)
            case 40 ... 47: attributes[.backgroundColor] = colorFromAnsiCode(code - 40)
            case 38, 48:
                let destinationKey: NSAttributedString.Key = codes[index] == 38 ? .foregroundColor : .backgroundColor

                /// format: `...38;5;x` or `...48;5;x`
                if codes.count >= 3, codes[index + 1] == 5 {
                    attributes[destinationKey] = colorFromAnsiCode(codes[index + 2])
                    break codesLoop
                }
                /// format: `...38;2;r;g;b` or `...48;2;r;g;b`
                if codes.count >= 5, codes[index + 1] == 2 {
                    attributes[destinationKey] = Color(
                        red: CGFloat(codes[index + 2]) / 255,
                        green: CGFloat(codes[index + 3]) / 255,
                        blue: CGFloat(codes[index + 4]) / 255,
                        alpha: 1
                    )
                    break codesLoop
                }
            default: break
            }
        }

        return attributes
    }

    /// Converting the `8, 16, 256 bits` code into `Color`
    private static func colorFromAnsiCode(_ code: Int) -> Color {
        if code < 16 {
            return standardAnsiColors[safe: code] ?? .black
        } else if code < 232 {
            let r = Double((code / 36) % 6) * 51.0 / 255.0
            let g = Double((code / 6) % 6) * 51.0 / 255.0
            let b = Double(code % 6) * 51.0 / 255.0
            return Color(red: r, green: g, blue: b, alpha: 1)
        } else {
            let gray = Double(8 + (code - 232) * 10) / 255.0
            return Color(red: gray, green: gray, blue: gray, alpha: 1)
        }
    }

    /// Standart ANSI `8, 16 bits` Colors
    private static let standardAnsiColors: [Color] = [
        .black,
        .red,
        .green,
        .yellow,
        .blue,
        .magenta,
        .cyan,
        .white,
        .init(red: 0.5, green: 0.5, blue: 0.5, alpha: 1), // bright black
        .init(red: 1.0, green: 0.5, blue: 0.5, alpha: 1), // bright red
        .init(red: 0.5, green: 1.0, blue: 0.5, alpha: 1), // bright green
        .init(red: 1.0, green: 1.0, blue: 0.5, alpha: 1), // bright yellow
        .init(red: 0.5, green: 0.5, blue: 1.0, alpha: 1), // bright blue
        .init(red: 1.0, green: 0.5, blue: 1.0, alpha: 1), // bright magenta
        .init(red: 0.5, green: 1.0, blue: 1.0, alpha: 1), // bright cyan
        .white, // bright white
    ]
}

extension NSFont {
    static func italicSystemFont(ofSize fontSize: CGFloat) -> Self? {
        let font = Self.systemFont(ofSize: Self.systemFontSize)
        let italicDescriptor = font.fontDescriptor.withSymbolicTraits(.italic)
        return Self(descriptor: italicDescriptor, size: fontSize)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        guard index < count else { return nil }
        return self[index]
    }
}
