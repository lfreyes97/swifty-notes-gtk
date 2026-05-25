import Adwaita
import CSpelling
import Foundation

/// Wires a ``FindReplaceBar`` to the editor's ``SourceBuffer`` /
/// ``SourceView``. Owns the search state — cached matches, the
/// active match index, the buffer-change subscription that
/// invalidates the cache — and routes the bar's callbacks into
/// concrete buffer mutations.
///
/// Why we don't use `GtkSourceSearchContext` here: the context's
/// occurrence count is computed on a background scan that lands
/// through `notify::occurrences-count`, which makes the unit-test
/// story significantly harder (have to spin the main loop until
/// the scan finishes, which is flaky on headless CI). Our notes
/// are small enough that a synchronous regex pass via
/// ``MarkdownSearchEngine.matches(in:query:options:)`` finishes
/// in microseconds — same engine the preview pane uses, so the
/// behaviour stays consistent across panes.
@MainActor
final class EditorSearchController {
    let bar: FindReplaceBar

    private let view: SourceView
    private let buffer: SourceBuffer

    /// Last query / options that produced ``matches``. Used to skip
    /// recomputation when nothing actually changed (e.g. when the
    /// buffer-change handler fires for unrelated edits — moves the
    /// cursor without altering text).
    private var lastQuery: String = ""
    private var lastOptions: SearchOptions = .init()

    /// Cached match ranges in document order. Indices into
    /// `buffer.text`. Invalidated by the buffer-change handler.
    private var matches: [Range<String.Index>] = []
    /// 0-based index into ``matches`` for the currently highlighted
    /// match. `nil` when no match is active (empty query, no hits,
    /// or just-cleared state).
    private var activeIndex: Int?

    /// Raw pointers to the two GtkTextTags we maintain on the
    /// editor buffer for the find bar. Created lazily via the
    /// CSpelling C shim (where g_object_set's varargs don't fight
    /// Swift). Persistent — once on the buffer's tag table they
    /// stay there for the buffer's lifetime; we toggle highlights
    /// by adding / removing the tags from ranges, not by recreating
    /// them.
    private var matchTagPointer: UnsafeMutableRawPointer?
    private var activeMatchTagPointer: UnsafeMutableRawPointer?

    init(bar: FindReplaceBar, view: SourceView, buffer: SourceBuffer) {
        self.bar = bar
        self.view = view
        self.buffer = buffer
        wireBarCallbacks()
        wireBufferChange()
    }
    // No explicit deinit / signal disconnect: the buffer-change
    // handler captures `[weak self]` and SignalConnection holds a
    // `weak var source` to the buffer, so once either the controller
    // or the buffer goes away the closure is effectively dead.

    /// Fires when a replace-all completes. Wired by MainWindow to
    /// surface a toast such as "Replaced 5 occurrences". Phase 3
    /// keeps this on the controller (not the bar) because toast
    /// presentation needs the ToastOverlay that lives on the
    /// window, not the search bar.
    var onReplaceAllCompleted: ((Int) -> Void)?

    private func wireBarCallbacks() {
        bar.onQueryChanged = { [weak self] query, options in
            self?.applyQuery(query, options: options)
        }
        bar.onStepNext = { [weak self] in self?.step(forward: true) }
        bar.onStepPrev = { [weak self] in self?.step(forward: false) }
        bar.onReplaceOne = { [weak self] in self?.replaceCurrent() }
        bar.onReplaceAll = { [weak self] in self?.replaceAll() }
        bar.onClose = { [weak self] in self?.clearState() }
    }

    private func wireBufferChange() {
        buffer.onChanged { [weak self] in
            guard let self else { return }
            // Buffer-mutating actions inside this controller (the
            // replace pipeline in Phase 3) also fire `changed`; we
            // rely on the cheap-recompute shortcut here when the
            // cached query is still empty to keep that a no-op
            // until something is actually being searched.
            guard !lastQuery.isEmpty else { return }
            recomputeMatches()
            updateBarCount()
        }
    }

    /// Re-run the search whenever the bar reports a new query or
    /// a toggled option. Empty query clears state (matches the
    /// "you're not actively searching" affordance — no count, no
    /// selection).
    private func applyQuery(_ query: String, options: SearchOptions) {
        lastQuery = query
        lastOptions = options
        if query.isEmpty {
            clearState()
            return
        }
        recomputeMatches()
        // Auto-step to first match relative to the current cursor
        // position — same affordance every GNOME find bar offers.
        // If there are zero matches we just update the count
        // (which will read "0" / "" via setMatchCount) without
        // moving the cursor.
        activeIndex = nil
        if matches.isEmpty {
            updateBarCount()
        } else {
            step(forward: true)
        }
    }

    private func recomputeMatches() {
        let text = buffer.text
        matches = MarkdownSearchEngine.matches(
            in: text,
            query: lastQuery,
            options: lastOptions,
        )
        // If we had an active match before the edit, try to keep
        // it pinned. Otherwise the existing index might point past
        // the end of the new matches array.
        if let active = activeIndex, active >= matches.count {
            activeIndex = matches.isEmpty ? nil : matches.count - 1
        }
        applyHighlightTags()
    }

    /// Re-apply the buffer-level tags so every match is visible
    /// (dim yellow background) and the active one stands out
    /// (saturated background + bold). Called after every match
    /// recomputation and after every step.
    private func applyHighlightTags() {
        let bufferPointer = UnsafeMutableRawPointer(buffer.opaquePointer)
        if matchTagPointer == nil {
            matchTagPointer = swifty_notes_search_create_match_tag(bufferPointer)
        }
        if activeMatchTagPointer == nil {
            activeMatchTagPointer = swifty_notes_search_create_active_tag(bufferPointer)
        }
        swifty_notes_search_clear_tags(bufferPointer, matchTagPointer, activeMatchTagPointer)
        guard !matches.isEmpty else { return }
        let text = buffer.text
        for (index, match) in matches.enumerated() {
            let startOffset = text.distance(from: text.startIndex, to: match.lowerBound)
            let endOffset = text.distance(from: text.startIndex, to: match.upperBound)
            let tag = (index == activeIndex) ? activeMatchTagPointer : matchTagPointer
            guard let tag else { continue }
            swifty_notes_search_apply_tag(
                bufferPointer,
                tag,
                Int32(startOffset),
                Int32(endOffset),
            )
        }
    }

    private func clearHighlightTags() {
        let bufferPointer = UnsafeMutableRawPointer(buffer.opaquePointer)
        swifty_notes_search_clear_tags(bufferPointer, matchTagPointer, activeMatchTagPointer)
    }

    /// Move to the next / previous match. Wraps around the document.
    /// First-time stepping after a query change starts from the
    /// match closest to (and at or after) the current cursor —
    /// i.e. typing "foo" jumps to the foo that's nearest below the
    /// caret, not back to the top.
    private func step(forward: Bool) {
        guard !matches.isEmpty else {
            updateBarCount()
            return
        }
        let text = buffer.text
        let newIndex: Int
        if let active = activeIndex {
            if forward {
                newIndex = (active + 1) % matches.count
            } else {
                newIndex = (active - 1 + matches.count) % matches.count
            }
        } else {
            // First step after a query change. Pick the first match
            // at or after the cursor (forward direction) or the last
            // one at or before the cursor (backward).
            let cursorOffset = buffer.selectedRange.lowerBound
            let cursorIndex = text.index(
                text.startIndex,
                offsetBy: min(cursorOffset, text.count),
            )
            if forward {
                newIndex = matches.firstIndex(where: { $0.lowerBound >= cursorIndex }) ?? 0
            } else {
                newIndex = matches.lastIndex(where: { $0.upperBound <= cursorIndex }) ?? (matches.count - 1)
            }
        }
        activeIndex = newIndex
        selectMatch(at: newIndex)
        // Refresh tag styling so the new active match wears the
        // saturated background and the previous one falls back to
        // the dim yellow.
        applyHighlightTags()
        updateBarCount()
    }

    private func selectMatch(at index: Int) {
        guard matches.indices.contains(index) else { return }
        let text = buffer.text
        let match = matches[index]
        let startOffset = text.distance(from: text.startIndex, to: match.lowerBound)
        let endOffset = text.distance(from: text.startIndex, to: match.upperBound)
        buffer.select(range: startOffset..<endOffset)
        scrollViewToCursor()
    }

    private func scrollViewToCursor() {
        // Scroll the active match into view. swift-adwaita's
        // SourceView doesn't expose a wrapper for
        // `gtk_text_view_scroll_to_mark`, so drop into the raw GTK
        // API. yalign = 0.3 lands the cursor at one-third from the
        // top of the visible area — the same target GtkSourceView
        // uses for its own stepped navigation.
        let viewPointer = UnsafeMutablePointer<GtkTextView>(view.opaquePointer)
        let bufferPointer = UnsafeMutablePointer<GtkTextBuffer>(buffer.opaquePointer)
        guard let insertMark = gtk_text_buffer_get_insert(bufferPointer) else { return }
        gtk_text_view_scroll_to_mark(
            viewPointer,
            insertMark,
            /* within_margin */ 0.0,
            /* use_align */ 1,
            /* xalign */ 0.0,
            /* yalign */ 0.3,
        )
    }

    private func updateBarCount() {
        if lastQuery.isEmpty {
            bar.setMatchCount(total: 0, activeDisplayIndex: nil)
            return
        }
        let total = matches.count
        let display: Int?
        if let activeIndex, total > 0 {
            display = activeIndex + 1
        } else {
            display = nil
        }
        bar.setMatchCount(total: total, activeDisplayIndex: display)
    }

    private func clearState() {
        lastQuery = ""
        matches.removeAll()
        activeIndex = nil
        bar.setMatchCount(total: 0, activeDisplayIndex: nil)
        clearHighlightTags()
    }

    /// Replace the currently active match with the bar's
    /// replacement string. In regex mode, expands `$1` / `$2` etc.
    /// backreferences against the matched substring. No-op when
    /// there's no active match or the bar is in read-only mode.
    private func replaceCurrent() {
        guard !bar.isReadOnly,
              let active = activeIndex,
              matches.indices.contains(active)
        else { return }
        let text = buffer.text
        let match = matches[active]
        let startOffset = text.distance(from: text.startIndex, to: match.lowerBound)
        let endOffset = text.distance(from: text.startIndex, to: match.upperBound)
        let matchedSubstring = String(text[match])
        let replacement = expandReplacement(for: matchedSubstring)

        // Single user-action so undo collapses the delete + insert
        // into one step.
        buffer.beginUserAction()
        buffer.delete(range: startOffset..<endOffset)
        buffer.insert(replacement, at: startOffset)
        buffer.endUserAction()

        // Buffer.onChanged has already fired and recomputed
        // `matches` against the new text. We want to land the next
        // step on the match that's now nearest after the cursor —
        // the active index from before the edit may no longer be
        // valid, so reset it and step forward.
        activeIndex = nil
        step(forward: true)
    }

    /// Replace every match in document order. Reports the count via
    /// ``onReplaceAllCompleted`` so the host window can surface a
    /// toast. No-op when there are no matches or the bar is in
    /// read-only mode.
    private func replaceAll() {
        guard !bar.isReadOnly, !matches.isEmpty else { return }
        let snapshot = matches
        let text = buffer.text

        // Pre-compute the replacement for each match against the
        // CURRENT buffer text, then apply them back-to-front so
        // earlier ranges aren't shifted by later edits.
        let replacements: [(Range<Int>, String)] = snapshot.map { range in
            let startOffset = text.distance(from: text.startIndex, to: range.lowerBound)
            let endOffset = text.distance(from: text.startIndex, to: range.upperBound)
            let matchedSubstring = String(text[range])
            let expanded = expandReplacement(for: matchedSubstring)
            return (startOffset..<endOffset, expanded)
        }

        buffer.beginUserAction()
        for (offsetRange, expanded) in replacements.reversed() {
            buffer.delete(range: offsetRange)
            buffer.insert(expanded, at: offsetRange.lowerBound)
        }
        buffer.endUserAction()

        // After mass replace there's nothing useful to "step to" —
        // the matches array has been invalidated and rebuilt by
        // buffer.onChanged. Drop the active selection so the user
        // isn't left looking at a stale highlight.
        activeIndex = nil
        updateBarCount()
        onReplaceAllCompleted?(snapshot.count)
    }

    /// Expand the bar's replacement template against a matched
    /// substring. In literal-search mode the template goes in
    /// verbatim; in regex mode we re-run the compiled regex against
    /// just the matched substring so we can call
    /// NSRegularExpression.replacementString, which knows about
    /// `$1` / `$2` / `$&` style references.
    private func expandReplacement(for matchedSubstring: String) -> String {
        let template = bar.replacement
        guard lastOptions.regex else { return template }
        guard let regex = MarkdownSearchEngine.compileRegex(query: lastQuery, options: lastOptions) else {
            return template
        }
        let nsRange = NSRange(matchedSubstring.startIndex..<matchedSubstring.endIndex, in: matchedSubstring)
        guard let result = regex.firstMatch(in: matchedSubstring, options: [], range: nsRange) else {
            return template
        }
        return regex.replacementString(
            for: result,
            in: matchedSubstring,
            offset: 0,
            template: template,
        )
    }
}

#if DEBUG
extension EditorSearchController {
    var debugMatchCount: Int { matches.count }
    var debugActiveIndex: Int? { activeIndex }
    var debugCachedQuery: String { lastQuery }
    var debugMatchTagCreated: Bool { matchTagPointer != nil }
    var debugActiveTagCreated: Bool { activeMatchTagPointer != nil }
    func debugRecomputeFromBuffer() {
        guard !lastQuery.isEmpty else { return }
        recomputeMatches()
        updateBarCount()
    }
}
#endif
