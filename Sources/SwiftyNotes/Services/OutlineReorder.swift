import Foundation

/// Pure markdown manipulation behind drag-to-reorder of outline rows.
///
/// Semantics (from the design's "Open questions / Drag semantics" note):
/// moving an H2 section moves the heading **and everything underneath
/// it until the next heading at ≤ same level**. Moving an H3 section
/// is the same rule: the H3 itself plus any deeper headings underneath
/// it, ending at the next H2 OR same-level H3, whichever comes first.
///
/// `movedMarkdown(_:movingID:beforeTargetID:headings:)` returns the
/// new markdown text, or `nil` if the move is illegal (drop on self,
/// drop into the moved subtree, unknown ids, etc.). Wiring it up to
/// the editor is the caller's job.
enum OutlineReorder {
    static func movedMarkdown(
        _ markdown: String,
        movingID: String,
        beforeTargetID: String,
        headings: [Heading],
    ) -> String? {
        guard movingID != beforeTargetID else { return nil }
        guard let source = headings.first(where: { $0.id == movingID }) else { return nil }
        guard let target = headings.first(where: { $0.id == beforeTargetID }) else { return nil }

        let sourceStart = source.line // 1-based
        var sourceEnd = totalLines(in: markdown) // 1-based inclusive sentinel
        for next in headings where next.line > source.line && next.level <= source.level {
            sourceEnd = next.line - 1
            break
        }

        // Drop target lives inside the source range — would be self-
        // overlap.
        if (sourceStart...sourceEnd).contains(target.line) { return nil }

        let lines = markdown.components(separatedBy: "\n")
        guard sourceStart >= 1, sourceEnd >= sourceStart, sourceEnd <= lines.count else { return nil }
        guard target.line >= 1, target.line <= lines.count else { return nil }

        let sourceSlice = Array(lines[(sourceStart - 1)...(sourceEnd - 1)])
        var withoutSource = Array(lines[0..<(sourceStart - 1)]) + Array(lines[sourceEnd..<lines.count])

        let targetNewLine: Int
        if target.line < sourceStart {
            targetNewLine = target.line
        } else {
            targetNewLine = target.line - sourceSlice.count
        }
        // Insert at 0-based index `targetNewLine - 1`.
        let insertionIndex = max(0, min(targetNewLine - 1, withoutSource.count))
        withoutSource.insert(contentsOf: sourceSlice, at: insertionIndex)
        return withoutSource.joined(separator: "\n")
    }

    /// Total line count of a markdown string treating a trailing
    /// newline as ending the previous line (not opening a new one).
    /// `"a\nb"` → 2; `"a\nb\n"` → 3 (matches the way swift-markdown
    /// reports `range.lowerBound.line`).
    private static func totalLines(in markdown: String) -> Int {
        markdown.components(separatedBy: "\n").count
    }
}
