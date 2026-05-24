import Adwaita
import CSpelling
import Foundation

/// Hides / shows sections of the editor when the user collapses or
/// expands H2 headings in the outline panel. Uses a single
/// `GtkTextTag` with `invisible: true` (created via the CSpelling C
/// shim, where we can pass the property through `g_object_set` without
/// fighting GValue from Swift). The tag spans from the end of a
/// collapsed H2 heading's line through the start of the next ≤ H2
/// heading (or buffer end).
///
/// Caveats:
/// - The line numbers come from the most recent ``Heading.line``
///   snapshot, which lags edits by one preview-refresh tick. After a
///   bulk edit the user might briefly see "wrong" sections folded
///   until the next refreshPreview commits — acceptable for the first
///   cut.
/// - Editing inside an invisible range still works (`gtk_text_iter`
///   doesn't skip invisible runs), but the typing won't show on
///   screen until the user expands the section.
@MainActor
enum OutlineEditorFolding {
    /// Apply / remove the invisible tag so the editor mirrors the
    /// outline's collapsed set. `collapsed` is the set of H2 heading
    /// ids the user has hidden in the outline; `headings` is the full
    /// flat list (passed so we can find each section's boundary).
    static func apply(buffer: SourceBuffer, collapsed: Set<String>, headings: [Heading]) {
        let bufferPtr = UnsafeMutableRawPointer(buffer.opaquePointer)
        guard let tagPtr = swifty_notes_outline_create_fold_tag(bufferPtr) else { return }

        swifty_notes_outline_clear_fold(bufferPtr, tagPtr)

        guard !collapsed.isEmpty else { return }

        let bufferLines = buffer.lineCount
        for (index, heading) in headings.enumerated() where heading.level == 2 && collapsed.contains(heading.id) {
            // Boundary = the next heading at level ≤ 2, or end of
            // buffer. `bufferLines + 1` is a safe sentinel since
            // `gtk_text_buffer_get_iter_at_line` clamps to the buffer
            // bounds.
            var boundaryLine = bufferLines + 1
            for next in headings[(index + 1)...] where next.level <= 2 {
                boundaryLine = next.line
                break
            }
            let zeroBasedHeading = max(heading.line - 1, 0)
            let zeroBasedBoundary = max(boundaryLine - 1, 0)
            swifty_notes_outline_apply_fold(
                bufferPtr,
                tagPtr,
                Int32(zeroBasedHeading),
                Int32(zeroBasedBoundary),
            )
        }
    }
}
