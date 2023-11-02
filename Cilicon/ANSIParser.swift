import AppKit

struct ANSIParser {
    typealias Color = NSColor
    typealias Font = NSFont
    static let fontName = "Andale Mono"
    private static let regex = /\[[0-9;]+m/

    static let defaultFont = Font.monospacedSystemFont(ofSize: Font.systemFontSize, weight: .regular)
    static let defaultAttributes: [NSAttributedString.Key: Any] = [
        .font: defaultFont as Any
    ]

    static func parse(_ log: String) -> AttributedString {
        var result = AttributedString()
        let ranges = log.ranges(of: regex)
        /// Create copy of ranges offset by 1, playing a role of next
        var nextRanges = ranges.dropFirst()
        nextRanges.append(log.endIndex ..< log.endIndex)

        for (range, next) in zip(ranges, nextRanges) {
            result.append(
                AttributedString(
                    /// String to format, is placed between the `range` and `next` ranged
                    String(log[range.upperBound ..< next.lowerBound]),
                    /// ANSI Code to parse
                    attributes: .init(attributesFor(ansiCode: String(log[range])))
                )
            )
        }

        /// Fallback in case failed to parse
        if result.characters.isEmpty {
            result.append(AttributedString(log.replacing(regex, with: ""), attributes: .init(Self.defaultAttributes)))
        }

        return result
    }

    /// Strips ANSI codes from the log
    static func stripped(_ log: String) -> String {
        log.replacing(regex, with: "")
    }

    private static func attributesFor(ansiCode: String) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = Self.defaultAttributes
        attributes[.font] = defaultFont
        let codes = ansiCode
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .decimalDigits.inverted) }
            .map { Int($0) ?? 0 }

        /// In case of `38` and `48` -> `break codesLoop` as final part of attribute format
        codesLoop: for (index, code) in codes.enumerated() {
            switch code {
            case 0:
                attributes = Self.defaultAttributes
            case 1:
                let newDescriptor = defaultFont.fontDescriptor.withSymbolicTraits(.bold)
                attributes[.font] = Font(descriptor: newDescriptor, size: Font.systemFontSize)
            case 3:
                let newDescriptor = defaultFont.fontDescriptor.withSymbolicTraits(.italic)
                attributes[.font] = Font(descriptor: newDescriptor, size: Font.systemFontSize)
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
        let font = NSFont(name: ANSIParser.fontName, size: systemFontSize) ?? .systemFont(ofSize: systemFontSize)
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
