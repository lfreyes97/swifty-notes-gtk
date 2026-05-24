import Adwaita
import Foundation

/// Editor scroll helpers used by the Outline panel, the breadcrumb,
/// and the Ctrl+G command palette. Phase 7 replaces the instant jump
/// with an animated `Adjustment.animate(...)` path; Phase 2 ships the
/// direct-jump baseline so the data wiring is testable end-to-end.
@MainActor
enum OutlineNavigation {
    /// Scrolls the source view so the given 1-based line sits near the
    /// top of the viewport (10 % margin from the edges). Uses GTK's
    /// underlying `gtk_text_view_scroll_to_iter` because swift-adwaita
    /// doesn't ship a scroll-to-line wrapper on ``SourceView`` yet.
    static func scrollEditor(view: SourceView, buffer: SourceBuffer, toLine line: Int) {
        let zeroBased = max(line - 1, 0)
        var iter = GtkTextIter()
        let bufferPtr = UnsafeMutablePointer<GtkTextBuffer>(buffer.opaquePointer)
        let viewPtr = UnsafeMutablePointer<GtkTextView>(view.opaquePointer)
        gtk_text_buffer_get_iter_at_line(bufferPtr, &iter, gint(zeroBased))
        // Also place the cursor at the heading so a follow-up keystroke
        // continues editing where the user just navigated.
        gtk_text_buffer_place_cursor(bufferPtr, &iter)
        // within_margin 0.1, use_align true, xalign 0, yalign 0 — same
        // call shape GtkSourceView's own Go-To-Line dialog uses, lands
        // the line near the top with a small breathing room.
        gtk_text_view_scroll_to_iter(viewPtr, &iter, 0.1, gtk_true(), 0.0, 0.0)
    }

    /// Aligns the preview pane to the editor's current scroll progress.
    /// Phase 7 replaces this proportional sync with a block-targeted
    /// scroll that lines the chosen heading up at the same Y as in the
    /// editor.
    static func scrollPreview(editorScroll: ScrolledWindow, previewScroll: ScrolledWindow) {
        PreviewScrollSync.sync(editor: editorScroll, preview: previewScroll)
    }
}

/// `gtk_true()` is not exposed in Swift — gboolean is a typedef for int
/// in GLib, and `1` works equivalently. Wrapped in a small helper so the
/// call sites read like the underlying API rather than peppering literal
/// `1`s around.
private func gtk_true() -> gboolean { 1 }

/// Heading-position queries used by ``OutlineScrollSpyDriver``. Both
/// return values are in the scroll container's coordinate system so
/// they can be compared directly against the `verticalAdjustment.value`.
@MainActor
enum OutlinePositions {
    /// Y of the rendered preview block at `heading.blockIndex`,
    /// relative to the preview's scrolled-window child. Returns `nil`
    /// when the index is out of bounds (the typing-deferred render
    /// hasn't committed yet) or the widget has no allocation (the
    /// preview pane is offscreen).
    static func previewY(for heading: Heading, in container: Box) -> Double? {
        let children = container.children()
        guard children.indices.contains(heading.blockIndex) else { return nil }
        return widgetY(of: children[heading.blockIndex])
    }

    /// Y of the source-view iter at `heading.line` (1-based). Uses
    /// `gtk_text_view_get_iter_location`, which fills a rectangle in
    /// the buffer's coordinate space; we translate that into widget
    /// coordinates and add the editor's current scroll offset so the
    /// number is directly comparable against the adjustment value.
    static func editorY(for heading: Heading, view: SourceView, buffer: SourceBuffer, scroll: ScrolledWindow) -> Double? {
        let bufferPtr = UnsafeMutablePointer<GtkTextBuffer>(buffer.opaquePointer)
        let viewPtr = UnsafeMutablePointer<GtkTextView>(view.opaquePointer)
        var iter = GtkTextIter()
        gtk_text_buffer_get_iter_at_line(bufferPtr, &iter, gint(max(heading.line - 1, 0)))
        var rect = GdkRectangle()
        gtk_text_view_get_iter_location(viewPtr, &iter, &rect)
        // `rect.y` is in buffer coordinates; the source view's vertical
        // adjustment also reports in buffer coords (it scrolls the whole
        // buffer, not the visible window), so they're directly
        // comparable. `scroll` is unused for now but kept on the
        // signature so the API matches the preview path one day.
        _ = scroll
        return Double(rect.y)
    }

    private static func widgetY(of widget: Widget) -> Double? {
        let widgetPtr = widget.widgetPointer
        var allocation = GtkAllocation()
        gtk_widget_get_allocation(widgetPtr, &allocation)
        guard allocation.height > 0 else { return nil }
        return Double(allocation.y)
    }
}
