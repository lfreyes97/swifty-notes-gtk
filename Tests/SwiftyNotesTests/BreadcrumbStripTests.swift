#if !os(macOS)
import Adwaita
import Foundation
@testable import SwiftyNotes
import Testing

struct BreadcrumbStripTests {
    @MainActor
    private static func makeStrip(suffix: String) throws -> BreadcrumbStrip {
        let app = Application(id: "me.spaceinbox.swiftynotes.tests.breadcrumb.\(suffix)")
        try app.register()
        return BreadcrumbStrip()
    }

    @Test @MainActor
    func `with no active heading, only the doc title is visible`() throws {
        let strip = try Self.makeStrip(suffix: "noactive")
        strip.update(
            docTitle: "Q3 Roadmap",
            headings: [
                .init(id: "overview", level: 2, text: "Overview", blockIndex: 0, line: 1),
            ],
            activeID: nil,
        )
        #expect(strip.docLabel.text == "Q3 Roadmap")
        #expect(strip.docLabel.visible == true)
        #expect(strip.sectionLabel.visible == false)
        #expect(strip.leafLabel.visible == false)
        #expect(strip.chevron1.visible == false)
        #expect(strip.chevron2.visible == false)
    }

    @Test @MainActor
    func `H1 active heading lands in the section slot with no leaf`() throws {
        let strip = try Self.makeStrip(suffix: "h1")
        strip.update(
            docTitle: "Doc",
            headings: [.init(id: "intro", level: 1, text: "Intro", blockIndex: 0, line: 1)],
            activeID: "intro",
        )
        #expect(strip.docLabel.text == "Doc")
        #expect(strip.sectionLabel.text == "Intro")
        #expect(strip.sectionLabel.visible == true)
        #expect(strip.leafLabel.visible == false)
        #expect(strip.chevron2.visible == false)
    }

    @Test @MainActor
    func `H2 active heading lands in the section slot with no leaf`() throws {
        let strip = try Self.makeStrip(suffix: "h2")
        strip.update(
            docTitle: "Doc",
            headings: [.init(id: "overview", level: 2, text: "Overview", blockIndex: 0, line: 1)],
            activeID: "overview",
        )
        #expect(strip.sectionLabel.text == "Overview")
        #expect(strip.leafLabel.visible == false)
    }

    @Test @MainActor
    func `H3 active heading uses the most recent H2 as its section`() throws {
        let strip = try Self.makeStrip(suffix: "h3parent")
        let headings: [Heading] = [
            .init(id: "doc",      level: 1, text: "Doc",       blockIndex: 0, line: 1),
            .init(id: "overview", level: 2, text: "Overview",  blockIndex: 1, line: 3),
            .init(id: "goals",    level: 3, text: "Goals",     blockIndex: 2, line: 5),
            .init(id: "features", level: 2, text: "Features",  blockIndex: 3, line: 7),
            .init(id: "outline",  level: 3, text: "Outline",   blockIndex: 4, line: 9),
        ]
        // Activate Goals — its parent is Overview, not Features.
        strip.update(docTitle: "Doc", headings: headings, activeID: "goals")
        #expect(strip.sectionLabel.text == "Overview")
        #expect(strip.leafLabel.text == "Goals")
        #expect(strip.leafLabel.visible == true)

        // Activate Outline — its parent is Features.
        strip.update(docTitle: "Doc", headings: headings, activeID: "outline")
        #expect(strip.sectionLabel.text == "Features")
        #expect(strip.leafLabel.text == "Outline")
    }

    @Test @MainActor
    func `empty doc title hides the leading segment and its chevron`() throws {
        let strip = try Self.makeStrip(suffix: "emptydoc")
        strip.update(docTitle: "", section: "Section", leaf: nil)
        #expect(strip.docLabel.visible == false)
        #expect(strip.chevron1.visible == false)
        #expect(strip.sectionLabel.visible == true)
        #expect(strip.sectionLabel.text == "Section")
    }
}
#endif
