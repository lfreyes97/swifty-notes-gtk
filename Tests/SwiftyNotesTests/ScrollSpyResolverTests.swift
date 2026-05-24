import Foundation
@testable import SwiftyNotes
import Testing

struct ScrollSpyResolverTests {
    @Test
    func `returns nil when there are no headings`() {
        #expect(ScrollSpyResolver.activeHeadingID(positions: [], scrollTop: 0) == nil)
    }

    @Test
    func `single heading at the top is active as soon as the viewport opens`() {
        // y=0 means the heading sits at the very top of the document.
        // With scrollTop=0 and anchorOffset=80, anchor is at y=80, so the
        // heading is well above the anchor → active.
        let positions = [(id: "intro", y: 0.0)]
        #expect(ScrollSpyResolver.activeHeadingID(positions: positions, scrollTop: 0) == "intro")
    }

    @Test
    func `returns nil when every heading is still below the anchor`() {
        // First heading at y=200, scrollTop=0 → anchor is at y=80 → no
        // heading is at/above the anchor yet.
        let positions = [(id: "first", y: 200.0)]
        #expect(ScrollSpyResolver.activeHeadingID(positions: positions, scrollTop: 0) == nil)
    }

    @Test
    func `as user scrolls past a heading, that heading becomes active`() {
        let positions = [
            (id: "h1", y: 0.0),
            (id: "h2", y: 500.0),
            (id: "h3", y: 1000.0),
        ]
        // Anchor (80) is past h1 but before h2 → h1 active.
        #expect(ScrollSpyResolver.activeHeadingID(positions: positions, scrollTop: 0) == "h1")
        // Anchor at 500 — exactly at h2's y → h2 active.
        #expect(ScrollSpyResolver.activeHeadingID(positions: positions, scrollTop: 420) == "h2")
        // Anchor between h2 and h3.
        #expect(ScrollSpyResolver.activeHeadingID(positions: positions, scrollTop: 700) == "h2")
        // Anchor past h3.
        #expect(ScrollSpyResolver.activeHeadingID(positions: positions, scrollTop: 1500) == "h3")
    }

    @Test
    func `ties at the same y favour the later heading in document order`() {
        // Mirrors the JS "prefer the deepest (most recent) at the anchor"
        // behaviour: when two headings collide on y, the later one wins,
        // matching what the user visually sees as "the most recent
        // heading they passed".
        let positions = [
            (id: "first",  y: 100.0),
            (id: "second", y: 100.0),
        ]
        #expect(ScrollSpyResolver.activeHeadingID(positions: positions, scrollTop: 100) == "second")
    }

    @Test
    func `custom anchor offset shifts the activation threshold`() {
        // Anchor at scrollTop + 0 means the very first pixel into the
        // viewport activates a heading. Useful for headerless layouts.
        let positions = [(id: "h", y: 0.0), (id: "h2", y: 50.0)]
        #expect(ScrollSpyResolver.activeHeadingID(positions: positions, scrollTop: 0, anchorOffset: 0) == "h")
        #expect(ScrollSpyResolver.activeHeadingID(positions: positions, scrollTop: 50, anchorOffset: 0) == "h2")
    }
}
