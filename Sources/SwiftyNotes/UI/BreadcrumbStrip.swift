import Adwaita
import Foundation

/// "You are here" strip above the editor in variant A — mirrors the
/// design's `.sn-breadcrumb` block. Three segments separated by chevron
/// glyphs: document title, the most recent H2 section, and the deepest
/// heading the user has scrolled past.
///
/// The strip stays a fixed 48 px tall so the editor toolbar and the
/// breadcrumb start their content at the same vertical position on
/// both sides of the split (matching the design's `height: 48 px`
/// rule — same logic as `EditorFormattingToolbar` padding).
@MainActor
final class BreadcrumbStrip {
    let root: Box

    // Exposed so widget tests can verify visibility / text without
    // having to reach in via accessibility lookups.
    let docLabel: Label
    let chevron1: Label
    let sectionLabel: Label
    let chevron2: Label
    let leafLabel: Label

    // Memoization keys so the scroll-spy hot path (which can fire
    // 60/s during a kinetic scroll, often with the same active id
    // back-to-back) doesn't re-write the three labels every tick —
    // each assignment invalidates Pango layout for that label.
    private var lastDocTitle: String?
    private var lastSection: String?
    private var lastLeaf: String?

    init() {
        docLabel = Label("")
        docLabel.xalign = 0
        docLabel.addCSSClass(.dimLabel)

        sectionLabel = Label("")
        sectionLabel.xalign = 0
        sectionLabel.addCSSClass(.dimLabel)
        sectionLabel.ellipsize = .end

        leafLabel = Label("")
        leafLabel.xalign = 0
        leafLabel.ellipsize = .end

        chevron1 = Label("›")
        chevron1.addCSSClass(.dimLabel)
        chevron2 = Label("›")
        chevron2.addCSSClass(.dimLabel)

        root = Box(orientation: .horizontal, spacing: 8)
        root.addCSSClass("sn-breadcrumb")
        root.marginStart = 36
        root.marginEnd = 36
        // 48 px height matches the editor toolbar's natural height
        // (9 px padding + 30 px button content). Wraps + fixed margins
        // place the doc title at the same vertical position as the
        // toolbar's first button on the other side of the split.
        root.setSizeRequest(height: 48)
        root.append(docLabel)
        root.append(chevron1)
        root.append(sectionLabel)
        root.append(chevron2)
        root.append(leafLabel)

        update(docTitle: "", section: nil, leaf: nil)
    }

    /// Refresh the three segments. `nil` segments are hidden (their
    /// preceding chevron disappears too) so a heading-less note shows
    /// only the doc title and an H1-only note shows "Doc › H1".
    func update(docTitle: String, section: String?, leaf: String?) {
        // Skip on no-change: the scroll-spy callback path calls this
        // ~60/s during a kinetic scroll, almost always with the same
        // (docTitle, section, leaf) tuple. Setting `label.text`
        // unconditionally triggers Pango re-layout for that label.
        if lastDocTitle == docTitle, lastSection == section, lastLeaf == leaf { return }
        lastDocTitle = docTitle
        lastSection = section
        lastLeaf = leaf

        docLabel.text = docTitle
        docLabel.visible = !docTitle.isEmpty

        if let section, !section.isEmpty {
            sectionLabel.text = section
            sectionLabel.visible = true
            chevron1.visible = !docTitle.isEmpty
        } else {
            sectionLabel.visible = false
            chevron1.visible = false
        }

        if let leaf, !leaf.isEmpty {
            leafLabel.text = leaf
            leafLabel.visible = true
            chevron2.visible = sectionLabel.visible
        } else {
            leafLabel.visible = false
            chevron2.visible = false
        }
    }

    /// Convenience: derive the section + leaf from the currently active
    /// heading and the headings list. H1 becomes the section
    /// (Doc › H1 alone, no leaf); H2 alone is the section; an H3+ row
    /// uses the most recent H2 above it as the section and itself as
    /// the leaf.
    func update(docTitle: String, headings: [Heading], activeID: String?) {
        guard let activeID, let active = headings.first(where: { $0.id == activeID }) else {
            update(docTitle: docTitle, section: nil, leaf: nil)
            return
        }
        switch active.level {
        case 1:
            update(docTitle: docTitle, section: active.text, leaf: nil)
        case 2:
            update(docTitle: docTitle, section: active.text, leaf: nil)
        default:
            // For H3+ find the most recent H2 above.
            var parent: Heading?
            for heading in headings {
                if heading.id == active.id { break }
                if heading.level == 2 { parent = heading }
            }
            update(docTitle: docTitle, section: parent?.text ?? "", leaf: active.text)
        }
    }
}
