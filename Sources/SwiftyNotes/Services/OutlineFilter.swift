import Foundation

/// Pure filter that drives what the Outline sidebar renders.
///
/// Rules mirror the design spec in `outline.jsx`:
///  - With an empty query, hide H3 (and deeper) rows whose parent H2 is
///    in the collapsed set; everything else passes through.
///  - With a non-empty query, do a case-insensitive substring match
///    against `heading.text` *and* ignore the collapsed set — the user
///    is searching, so a match under a collapsed section must still
///    surface (the panel would otherwise hide what it's claiming to
///    find).
///  - H1 is never affected by collapse — collapse only governs the
///    "children of H2" rule. Collapsing the document-level H1 would
///    silently hide the entire outline; we leave that decision to the
///    panel-visibility toggle, not the per-section chevron.
enum OutlineFilter {
    static func visible(
        headings: [Heading],
        query: String,
        collapsed: Set<String>,
    ) -> [Heading] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercaseQuery = trimmed.lowercased()
        let hasQuery = !trimmed.isEmpty
        var currentH2: String?
        var result: [Heading] = []
        for heading in headings {
            if heading.level <= 2 {
                if heading.level == 2 { currentH2 = heading.id }
                if !hasQuery || heading.text.lowercased().contains(lowercaseQuery) {
                    result.append(heading)
                }
                continue
            }
            // Level >= 3: respect collapsed parent only when not searching.
            if !hasQuery, let parent = currentH2, collapsed.contains(parent) {
                continue
            }
            if !hasQuery || heading.text.lowercased().contains(lowercaseQuery) {
                result.append(heading)
            }
        }
        return result
    }
}
