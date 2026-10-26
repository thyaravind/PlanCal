import Foundation

enum MarkdownBlockStyle: Equatable, Sendable {
    case heading(Int)
    case bulletList
    case orderedList
    case taskList
    case blockquote
}

enum MarkdownBlockFormatter {
    nonisolated static func transform(
        _ text: String,
        to style: MarkdownBlockStyle
    ) -> String {
        let lines = text.components(separatedBy: "\n")
        let meaningfulLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !meaningfulLines.isEmpty else { return text }

        let removesStyle = meaningfulLines.allSatisfy { hasStyle(style, in: $0) }
        return lines.map { line in
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return line }

            let indentation = String(line.prefix { $0 == " " || $0 == "\t" })
            var content = String(line.dropFirst(indentation.count))
            content = stripRelevantPrefix(from: content, for: style)

            guard !removesStyle else { return indentation + content }
            return indentation + prefix(for: style) + content
        }
        .joined(separator: "\n")
    }

    private nonisolated static func hasStyle(
        _ style: MarkdownBlockStyle,
        in line: String
    ) -> Bool {
        let content = line.drop { $0 == " " || $0 == "\t" }
        return String(content).range(
            of: requestedPattern(for: style),
            options: .regularExpression
        ) != nil
    }

    private nonisolated static func stripRelevantPrefix(
        from content: String,
        for style: MarkdownBlockStyle
    ) -> String {
        let pattern: String
        switch style {
        case .heading:
            pattern = #"^#{1,6}[ \t]+"#
        case .bulletList, .orderedList, .taskList:
            pattern = #"^(?:[-+*][ \t]+\[[ xX]\][ \t]+|[-+*][ \t]+|\d+[.)][ \t]+)"#
        case .blockquote:
            pattern = #"^>[ \t]+"#
        }

        return content.replacingOccurrences(
            of: pattern,
            with: "",
            options: .regularExpression
        )
    }

    private nonisolated static func requestedPattern(
        for style: MarkdownBlockStyle
    ) -> String {
        switch style {
        case .heading(let level):
            guard level > 0 else { return #"^#{1,6}[ \t]+"# }
            return "^#{\(min(6, level))}[ \\t]+"
        case .bulletList:
            return #"^[-+*][ \t]+(?!\[[ xX]\][ \t]+)"#
        case .orderedList:
            return #"^\d+[.)][ \t]+"#
        case .taskList:
            return #"^[-+*][ \t]+\[[ xX]\][ \t]+"#
        case .blockquote:
            return #"^>[ \t]+"#
        }
    }

    private nonisolated static func prefix(for style: MarkdownBlockStyle) -> String {
        switch style {
        case .heading(let level):
            return level > 0 ? String(repeating: "#", count: min(6, level)) + " " : ""
        case .bulletList:
            return "- "
        case .orderedList:
            return "1. "
        case .taskList:
            return "- [ ] "
        case .blockquote:
            return "> "
        }
    }
}
