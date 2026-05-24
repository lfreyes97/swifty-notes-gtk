import Foundation

/// Pure ranker used by the Ctrl+G command palette to order headings by
/// match quality. Mirrors the rules in `palette.jsx`:
///
///   score 0 — query matches at index 0 of the heading text
///   score 1 — matches later in the heading text
///   score 2 — matches only in the parent H2's text
///
/// Ties are broken by document order — the sort is stable, which lets
/// the palette show predictable results when several headings rank the
/// same. With an empty (or whitespace-only) query, the ranker returns
/// the input unchanged; the palette then groups recents + everything
/// itself.
enum PaletteRanker {
    static func rank(headings: [Heading], query: String) -> [Heading] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return headings }
        let needle = trimmed.lowercased()

        // Map each heading id to its parent H2's text. H1 and H2 rows
        // have no parent; H3+ rows take the most recent H2.
        var parentText: [String: String] = [:]
        var currentH2Text: String?
        for heading in headings {
            if heading.level == 2 { currentH2Text = heading.text }
            if heading.level >= 3, let parent = currentH2Text {
                parentText[heading.id] = parent
            }
        }

        struct Ranked {
            let heading: Heading
            let score: Int
            let order: Int
        }
        var ranked: [Ranked] = []
        for (idx, heading) in headings.enumerated() {
            let title = heading.text.lowercased()
            let parent = parentText[heading.id]?.lowercased() ?? ""
            let titleHit = title.range(of: needle)
            let parentHit = parent.range(of: needle)
            if titleHit == nil, parentHit == nil { continue }
            let score: Int
            if let titleHit {
                score = titleHit.lowerBound == title.startIndex ? 0 : 1
            } else {
                score = 2
            }
            ranked.append(Ranked(heading: heading, score: score, order: idx))
        }
        ranked.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score < rhs.score }
            return lhs.order < rhs.order
        }
        return ranked.map(\.heading)
    }
}
