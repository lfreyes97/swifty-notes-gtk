import Foundation

/// Pure-function flipper for `[ ]` ↔ `[x]` task-list checkboxes
/// addressed by their 0-based index in document order. Used by the
/// preview's clickable-checkbox path: the preview hands the source
/// markdown plus the task-item index it bound to a click; this
/// service produces the rewritten markdown that gets persisted.
///
/// Recognises a checkbox marker only when it sits immediately after a
/// `-`, `*`, `+`, or `<n>.`/`<n>)` list bullet — the same shape the
/// renderer's task-item scanner accepts. Stray `[x]` / `[ ]` text in
/// prose is left alone.
public enum TaskListToggle {
    public static func toggle(in markdown: String, atTaskIndex target: Int) -> String {
        guard target >= 0 else { return markdown }
        let lines = markdown.components(separatedBy: "\n")
        var taskCounter = 0
        var rewritten: [String] = []
        rewritten.reserveCapacity(lines.count)
        var didToggle = false
        for line in lines {
            guard !didToggle, let markerRange = taskMarkerRange(in: line) else {
                rewritten.append(line)
                continue
            }
            if taskCounter == target {
                let current = String(line[markerRange])
                let flipped = current == "[ ]" ? "[x]" : "[ ]"
                var newLine = line
                newLine.replaceSubrange(markerRange, with: flipped)
                rewritten.append(newLine)
                didToggle = true
            } else {
                taskCounter += 1
                rewritten.append(line)
            }
        }
        return rewritten.joined(separator: "\n")
    }

    private static func taskMarkerRange(in line: String) -> Range<String.Index>? {
        var idx = line.startIndex
        while idx < line.endIndex, line[idx] == " " || line[idx] == "\t" {
            idx = line.index(after: idx)
        }
        guard idx < line.endIndex else { return nil }
        if line[idx] == "-" || line[idx] == "*" || line[idx] == "+" {
            idx = line.index(after: idx)
        } else {
            // Ordered list marker: digits followed by `.` or `)`.
            let numStart = idx
            while idx < line.endIndex, line[idx].isNumber {
                idx = line.index(after: idx)
            }
            guard idx > numStart, idx < line.endIndex, line[idx] == "." || line[idx] == ")" else {
                return nil
            }
            idx = line.index(after: idx)
        }
        guard idx < line.endIndex, line[idx] == " " else { return nil }
        idx = line.index(after: idx)
        // Need exactly `[` then ` ` or `x`/`X` then `]`.
        guard idx < line.endIndex, line[idx] == "[" else { return nil }
        let bracketStart = idx
        let middle = line.index(after: idx)
        guard middle < line.endIndex else { return nil }
        let middleChar = line[middle]
        guard middleChar == " " || middleChar == "x" || middleChar == "X" else { return nil }
        let closing = line.index(after: middle)
        guard closing < line.endIndex, line[closing] == "]" else { return nil }
        return bracketStart..<line.index(after: closing)
    }
}
