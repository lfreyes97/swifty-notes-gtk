import Foundation

/// A heading discovered in a Markdown note. Used by the Outline panel,
/// the breadcrumb strip, and the Ctrl+G command palette.
///
/// - `id`: stable slug derived from the heading text + occurrence index
///   so click-to-scroll, scroll-spy, and recent-jump state can refer to
///   the heading across re-renders without colliding on duplicates.
/// - `blockIndex`: 0-based position of the heading among the rendered
///   blocks. Used to drive ``MarkdownPreview`` scroll-to-block.
/// - `line`: 1-based source line in the editor buffer. Used to drive
///   ``GtkSourceView`` `scroll_to_iter`.
struct Heading: Sendable, Equatable, Hashable {
    let id: String
    let level: Int
    let text: String
    let blockIndex: Int
    let line: Int
}
