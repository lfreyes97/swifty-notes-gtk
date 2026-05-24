import Adwaita
import Foundation

/// Ctrl+G quick-jump palette. Mirrors the design's `.sn-pal` overlay:
/// a centered modal `Window` with a `SearchEntry` on top, a grouped
/// `ListBox` of headings underneath, and a keyboard-hint footer below.
///
/// Behaviour contract (from `palette.jsx`):
///   * empty query → "Recent jumps" group (max 5) then "All headings"
///     in document order, excluding entries already in the recents.
///   * non-empty query → "Matches" group ranked by ``PaletteRanker``.
///   * keyboard: ↑/↓ move highlight, PgUp/PgDn move by 5, Home/End
///     go to first/last, Enter activates, Esc + Ctrl+G dismiss.
///   * the currently in-view heading is rendered with a "current"
///     pill so the user knows where they are even when they search.
@MainActor
final class CommandPaletteWindow {
    private let window: Window
    private let searchEntry: SearchEntry
    private let list: ListBox
    private let footerCount: Label
    private let emptyLabel: Label
    private let scroll: ScrolledWindow

    private let headings: [Heading]
    private let recents: [String]
    private let currentID: String?
    private let parentText: [String: String]
    private let onPick: (String) -> Void

    private var items: [Heading] = []
    private var rowWidgets: [ListBoxRow] = []
    private var highlightIndex: Int = 0

    init(
        transientFor: ApplicationWindow,
        headings: [Heading],
        currentID: String?,
        recents: [String],
        onPick: @escaping (String) -> Void,
    ) {
        self.headings = headings
        self.recents = recents
        self.currentID = currentID
        self.onPick = onPick

        // Build the H3+ → parent H2 lookup once; the ranker doesn't
        // need it but our row rendering does (parent breadcrumb on
        // H3+ rows).
        var parentMap: [String: String] = [:]
        var currentH2: String?
        for heading in headings {
            if heading.level == 2 { currentH2 = heading.text }
            if heading.level >= 3, let parent = currentH2 {
                parentMap[heading.id] = parent
            }
        }
        parentText = parentMap

        window = Window()
        window.title = "Jump to heading"
        window.modal = true
        window.transientFor = transientFor
        window.setDefaultSize(width: 640, height: 480)

        searchEntry = SearchEntry()
        searchEntry.placeholderText = "Jump to heading…"
        searchEntry.hexpand = true
        searchEntry.searchDelay = 0 // palette should feel instant; debounce already happens at keystroke level

        list = ListBox()
        list.selectionMode = .browse
        list.activateOnSingleClick = true
        list.addCSSClass("navigation-sidebar")
        list.setAccessibleLabel("Jump-to-heading results")

        scroll = ScrolledWindow(child: list)
        scroll.setPolicy(horizontal: .never, vertical: .automatic)
        scroll.vexpand = true
        scroll.minContentHeight = 320

        emptyLabel = Label("")
        emptyLabel.wrap = true
        emptyLabel.xalign = 0
        emptyLabel.addCSSClass(.dimLabel)
        emptyLabel.marginTop = 24
        emptyLabel.marginBottom = 12

        footerCount = Label("")
        footerCount.addCSSClass(.dimLabel)
        footerCount.addCSSClass("caption")
        footerCount.xalign = 1

        let searchRow = Box(orientation: .horizontal, spacing: 8)
        searchRow.setMargins(12)
        let searchIcon = Image(icon: .systemSearch)
        searchIcon.addCSSClass(.dimLabel)
        searchRow.append(searchIcon)
        searchRow.append(searchEntry)

        let footerRow = Box(orientation: .horizontal, spacing: 16)
        footerRow.marginStart = 12
        footerRow.marginEnd = 12
        footerRow.marginTop = 6
        footerRow.marginBottom = 8
        let kbdHints = Label("↑↓ navigate · ↵ jump · Esc close")
        kbdHints.addCSSClass(.dimLabel)
        kbdHints.addCSSClass("caption")
        kbdHints.xalign = 0
        kbdHints.hexpand = true
        footerRow.append(kbdHints)
        footerRow.append(footerCount)

        let content = Box(orientation: .vertical, spacing: 0)
        content.append(searchRow)
        content.append(Separator())
        content.append(scroll)
        content.append(emptyLabel)
        content.append(Separator())
        content.append(footerRow)

        window.content = content
        wireSignals()
        rebuildItems()
    }

    func present() {
        // Re-derive items with currentID highlighted before the window
        // ever paints — otherwise the first render briefly shows the
        // 0th row highlighted before our currentID resolution kicks in.
        rebuildItems()
        window.present()
        _ = searchEntry.grabFocus()
    }

    private func wireSignals() {
        searchEntry.onSearchChanged { [weak self] in
            self?.rebuildItems()
        }

        list.onRowActivated { [weak self] row in
            guard let self else { return }
            let index = Int(row.index)
            guard items.indices.contains(index) else { return }
            commit(items[index].id)
        }

        // Window-level shortcuts intercept before SearchEntry's default
        // cursor-movement handlers, so the user can type AND navigate
        // the list without having to leave the input.
        window.addKeyboardShortcut("Down") { [weak self] in
            self?.move(by: 1); return true
        }
        window.addKeyboardShortcut("Up") { [weak self] in
            self?.move(by: -1); return true
        }
        window.addKeyboardShortcut("Page_Down") { [weak self] in
            self?.move(by: 5); return true
        }
        window.addKeyboardShortcut("Page_Up") { [weak self] in
            self?.move(by: -5); return true
        }
        window.addKeyboardShortcut("Home") { [weak self] in
            self?.setHighlight(0); return true
        }
        window.addKeyboardShortcut("End") { [weak self] in
            guard let self else { return true }
            setHighlight(items.count - 1)
            return true
        }
        window.addKeyboardShortcut("Return") { [weak self] in
            self?.activateHighlighted(); return true
        }
        window.addKeyboardShortcut("KP_Enter") { [weak self] in
            self?.activateHighlighted(); return true
        }
        window.addKeyboardShortcut("Escape") { [weak self] in
            self?.window.close(); return true
        }
        // Ctrl+G toggles — pressing again closes the palette.
        window.addKeyboardShortcut("<Primary>g") { [weak self] in
            self?.window.close(); return true
        }
    }

    private func rebuildItems() {
        let query = searchEntry.text
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            items = emptyQueryItems()
        } else {
            items = PaletteRanker.rank(headings: headings, query: trimmed)
        }
        list.removeAll()
        rowWidgets.removeAll()
        for heading in items {
            let row = makeRow(for: heading, query: trimmed)
            list.append(row)
            rowWidgets.append(row)
        }

        if items.isEmpty {
            emptyLabel.text = trimmed.isEmpty
                ? "No headings in this note."
                : "No headings match \"\(trimmed)\""
            emptyLabel.visible = true
            scroll.visible = false
        } else {
            emptyLabel.visible = false
            scroll.visible = true
        }

        footerCount.text = "\(items.count) of \(headings.count)"

        // Default highlight: currentID if visible, else first row.
        if trimmed.isEmpty,
           let currentID,
           let idx = items.firstIndex(where: { $0.id == currentID })
        {
            setHighlight(idx)
        } else {
            setHighlight(0)
        }
    }

    private func emptyQueryItems() -> [Heading] {
        let recentSet = Set(recents)
        var out: [Heading] = []
        // Recent jumps first, in newest-first order — these came in as
        // ids; resolve back to headings via the full list.
        for id in recents {
            if let heading = headings.first(where: { $0.id == id }) {
                out.append(heading)
            }
        }
        for heading in headings where !recentSet.contains(heading.id) {
            out.append(heading)
        }
        return out
    }

    private func makeRow(for heading: Heading, query: String) -> ListBoxRow {
        let row = ListBoxRow()
        row.addCSSClass("sn-pal-row")

        let pill = Label("H\(heading.level)")
        pill.addCSSClass("sn-pal-pill")
        pill.addCSSClass("sn-pal-pill-h\(heading.level)")
        pill.marginEnd = 6

        let parentLabel = Label("")
        parentLabel.addCSSClass(.dimLabel)
        if let parent = parentText[heading.id], heading.level >= 3 {
            parentLabel.text = "\(parent) ›"
            parentLabel.visible = true
        } else {
            parentLabel.visible = false
        }
        parentLabel.marginEnd = 4

        let leafLabel = Label("")
        if query.isEmpty {
            leafLabel.useMarkup = false
            leafLabel.text = heading.text
        } else {
            leafLabel.useMarkup = true
            leafLabel.text = Self.highlightedMarkup(heading.text, query: query)
        }
        leafLabel.ellipsize = .end
        leafLabel.hexpand = true
        leafLabel.xalign = 0

        let container = Box(orientation: .horizontal, spacing: 6)
        container.setMargins(8)
        container.append(pill)
        container.append(parentLabel)
        container.append(leafLabel)
        if heading.id == currentID {
            let hint = Label("current")
            hint.addCSSClass("sn-pal-hint")
            hint.addCSSClass(.dimLabel)
            container.append(hint)
            row.addCSSClass("is-current")
        }
        row.child = container
        return row
    }

    private func setHighlight(_ index: Int) {
        guard !items.isEmpty else {
            highlightIndex = 0
            return
        }
        let clamped = max(0, min(index, items.count - 1))
        highlightIndex = clamped
        list.selectRow(at: clamped)
        // Scroll the highlighted row into view — the GTK ListBox doesn't
        // auto-scroll on programmatic selection.
        if rowWidgets.indices.contains(clamped) {
            rowWidgets[clamped].grabFocus()
        }
    }

    private func move(by delta: Int) {
        setHighlight(highlightIndex + delta)
    }

    private func activateHighlighted() {
        guard items.indices.contains(highlightIndex) else { return }
        commit(items[highlightIndex].id)
    }

    private func commit(_ id: String) {
        onPick(id)
        window.close()
    }

    /// Same Pango entity escape + yellow highlight as the outline rows.
    private static func highlightedMarkup(_ text: String, query: String) -> String {
        let lowerText = text.lowercased()
        let lowerQuery = query.lowercased()
        guard let range = lowerText.range(of: lowerQuery) else {
            return Self.escapeMarkup(text)
        }
        let pre = String(text[..<range.lowerBound])
        let hit = String(text[range])
        let post = String(text[range.upperBound...])
        return "\(escapeMarkup(pre))<span background=\"#f5c211\" foreground=\"#1e1e1e\">\(escapeMarkup(hit))</span>\(escapeMarkup(post))"
    }

    private static func escapeMarkup(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        for char in text {
            switch char {
            case "&": result.append("&amp;")
            case "<": result.append("&lt;")
            case ">": result.append("&gt;")
            case "\"": result.append("&quot;")
            case "'": result.append("&apos;")
            default: result.append(char)
            }
        }
        return result
    }
}

#if DEBUG
extension CommandPaletteWindow {
    var debugItems: [Heading] { items }
    var debugHighlightIndex: Int { highlightIndex }
    func debugSetQuery(_ q: String) {
        searchEntry.text = q
        rebuildItems()
    }
    func debugActivateHighlighted() { activateHighlighted() }
    func debugMove(by delta: Int) { move(by: delta) }
}
#endif
