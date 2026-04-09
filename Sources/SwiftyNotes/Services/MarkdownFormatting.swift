import Foundation

enum MarkdownFormattingAction: CaseIterable, Hashable {
    case heading
    case bold
    case italic
    case code
    case link
    case quote
    case bulletList
    case numberedList
    case taskList

    var accessibilityLabel: String {
        switch self {
        case .heading:
            "Heading"
        case .bold:
            "Bold"
        case .italic:
            "Italic"
        case .code:
            "Code"
        case .link:
            "Link"
        case .quote:
            "Quote"
        case .bulletList:
            "Bulleted List"
        case .numberedList:
            "Numbered List"
        case .taskList:
            "Task List"
        }
    }

    var tooltip: String {
        switch self {
        case .heading:
            "Turn the current line into a heading"
        case .bold:
            "Wrap the selection in bold markdown"
        case .italic:
            "Wrap the selection in italic markdown"
        case .code:
            "Insert inline code or a fenced code block"
        case .link:
            "Insert a markdown link"
        case .quote:
            "Prefix the selected lines as a quote"
        case .bulletList:
            "Prefix the selected lines as a bulleted list"
        case .numberedList:
            "Prefix the selected lines as a numbered list"
        case .taskList:
            "Prefix the selected lines as a task list"
        }
    }

    var iconName: String? {
        switch self {
        case .bold:
            "format-text-bold-symbolic"
        case .italic:
            "format-text-italic-symbolic"
        case .link:
            "insert-link-symbolic"
        case .quote:
            "format-justify-left-symbolic"
        case .bulletList:
            "view-list-bullet-symbolic"
        case .numberedList:
            "view-list-ordered-symbolic"
        default:
            nil
        }
    }

    var shortLabel: String? {
        switch self {
        case .heading:
            "H1"
        case .quote:
            "Quote"
        case .code:
            "</>"
        case .bulletList:
            "Bullets"
        case .numberedList:
            "1."
        case .taskList:
            "[ ]"
        default:
            nil
        }
    }
}

struct MarkdownFormattingEdit: Equatable {
    let replacementRange: Range<Int>
    let replacementText: String
    let selectedRange: Range<Int>
}

enum MarkdownFormatting {
    static func edit(
        for action: MarkdownFormattingAction,
        in text: String,
        selection: Range<Int>
    ) -> MarkdownFormattingEdit {
        let normalizedSelection = normalize(selection, in: text)
        switch action {
        case .bold:
            return wrapInline(in: text, selection: normalizedSelection, prefix: "**", suffix: "**", placeholder: "bold")
        case .italic:
            return wrapInline(in: text, selection: normalizedSelection, prefix: "*", suffix: "*", placeholder: "emphasis")
        case .code:
            return formatCode(in: text, selection: normalizedSelection)
        case .link:
            return formatLink(in: text, selection: normalizedSelection)
        case .heading:
            return prefixLines(in: text, selection: normalizedSelection) { _ in "# " }
        case .quote:
            return prefixLines(in: text, selection: normalizedSelection) { _ in "> " }
        case .bulletList:
            return prefixLines(in: text, selection: normalizedSelection) { _ in "- " }
        case .numberedList:
            return prefixLines(in: text, selection: normalizedSelection) { index in "\(index + 1). " }
        case .taskList:
            return prefixLines(in: text, selection: normalizedSelection) { _ in "- [ ] " }
        }
    }

    private static func wrapInline(
        in text: String,
        selection: Range<Int>,
        prefix: String,
        suffix: String,
        placeholder: String
    ) -> MarkdownFormattingEdit {
        let selectedText = substring(in: text, range: selection)
        let innerText = selectedText.isEmpty ? placeholder : selectedText
        let replacementText = prefix + innerText + suffix
        let selectionStart = selection.lowerBound + prefix.count
        let selectedRange = selectionStart..<(selectionStart + innerText.count)
        return MarkdownFormattingEdit(
            replacementRange: selection,
            replacementText: replacementText,
            selectedRange: selectedRange
        )
    }

    private static func formatCode(
        in text: String,
        selection: Range<Int>
    ) -> MarkdownFormattingEdit {
        let selectedText = substring(in: text, range: selection)
        if selectedText.contains("\n") {
            let replacementText = "```\n\(selectedText)\n```"
            let selectionStart = selection.lowerBound + 4
            return MarkdownFormattingEdit(
                replacementRange: selection,
                replacementText: replacementText,
                selectedRange: selectionStart..<(selectionStart + selectedText.count)
            )
        }
        return wrapInline(in: text, selection: selection, prefix: "`", suffix: "`", placeholder: "code")
    }

    private static func formatLink(
        in text: String,
        selection: Range<Int>
    ) -> MarkdownFormattingEdit {
        let selectedText = substring(in: text, range: selection)
        let label = selectedText.isEmpty ? "link text" : selectedText
        let urlPlaceholder = "https://"
        let replacementText = "[\(label)](\(urlPlaceholder))"
        let selectionStart: Int
        let selectionLength: Int
        if selectedText.isEmpty {
            selectionStart = selection.lowerBound + 1
            selectionLength = label.count
        } else {
            selectionStart = selection.lowerBound + 3 + label.count
            selectionLength = urlPlaceholder.count
        }
        return MarkdownFormattingEdit(
            replacementRange: selection,
            replacementText: replacementText,
            selectedRange: selectionStart..<(selectionStart + selectionLength)
        )
    }

    private static func prefixLines(
        in text: String,
        selection: Range<Int>,
        prefix: (Int) -> String
    ) -> MarkdownFormattingEdit {
        let lineRange = linesCovered(by: selection, in: text)
        let block = substring(in: text, range: lineRange)
        let lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let replacementText = lines.enumerated().map { index, line in
            prefix(index) + line
        }.joined(separator: "\n")
        return MarkdownFormattingEdit(
            replacementRange: lineRange,
            replacementText: replacementText,
            selectedRange: lineRange.lowerBound..<(lineRange.lowerBound + replacementText.count)
        )
    }

    private static func linesCovered(by selection: Range<Int>, in text: String) -> Range<Int> {
        let count = text.count
        let lowerBound = max(0, min(selection.lowerBound, count))
        let upperBound = max(0, min(selection.upperBound, count))
        let lastSelectedOffset = upperBound > lowerBound ? upperBound - 1 : upperBound
        let start = lineStart(containing: lowerBound, in: text)
        let end = lineEnd(containing: lastSelectedOffset, in: text)
        return start..<end
    }

    private static func lineStart(containing offset: Int, in text: String) -> Int {
        let clamped = max(0, min(offset, text.count))
        let endIndex = index(at: clamped, in: text)
        let prefix = text[..<endIndex]
        return (prefix.lastIndex(of: "\n").map { text.distance(from: text.startIndex, to: text.index(after: $0)) }) ?? 0
    }

    private static func lineEnd(containing offset: Int, in text: String) -> Int {
        let clamped = max(0, min(offset, text.count))
        let startIndex = index(at: clamped, in: text)
        guard let newlineIndex = text[startIndex...].firstIndex(of: "\n") else {
            return text.count
        }
        return text.distance(from: text.startIndex, to: newlineIndex)
    }

    private static func substring(in text: String, range: Range<Int>) -> String {
        let normalized = normalize(range, in: text)
        let start = index(at: normalized.lowerBound, in: text)
        let end = index(at: normalized.upperBound, in: text)
        return String(text[start..<end])
    }

    private static func normalize(_ range: Range<Int>, in text: String) -> Range<Int> {
        let count = text.count
        let lower = max(0, min(range.lowerBound, count))
        let upper = max(lower, min(range.upperBound, count))
        return lower..<upper
    }

    private static func index(at offset: Int, in text: String) -> String.Index {
        text.index(text.startIndex, offsetBy: max(0, min(offset, text.count)))
    }
}
