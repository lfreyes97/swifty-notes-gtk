import Foundation
@testable import SwiftyNotes
import Testing

struct HeadingSlugTests {
    @Test
    func `simple ASCII text becomes lowercase kebab-case`() {
        var occ: [String: Int] = [:]
        #expect(HeadingSlug.slug("Hello World", occurrences: &occ) == "hello-world")
    }

    @Test
    func `mixed punctuation collapses to single dashes`() {
        var occ: [String: Int] = [:]
        #expect(HeadingSlug.slug("Goals & non-goals!", occurrences: &occ) == "goals-non-goals")
    }

    @Test
    func `leading and trailing punctuation is trimmed`() {
        var occ: [String: Int] = [:]
        #expect(HeadingSlug.slug("--Hello--", occurrences: &occ) == "hello")
        #expect(HeadingSlug.slug("...World...", occurrences: &occ) == "world")
    }

    @Test
    func `consecutive whitespace collapses to single dash`() {
        var occ: [String: Int] = [:]
        #expect(HeadingSlug.slug("foo   bar", occurrences: &occ) == "foo-bar")
        #expect(HeadingSlug.slug("a\tb\nc", occurrences: &occ) == "a-b-c")
    }

    @Test
    func `empty or punctuation-only headings fall back to section`() {
        var occ: [String: Int] = [:]
        #expect(HeadingSlug.slug("", occurrences: &occ) == "section")
        #expect(HeadingSlug.slug("---", occurrences: &occ) == "section-2")
        #expect(HeadingSlug.slug("???", occurrences: &occ) == "section-3")
    }

    @Test
    func `non-ASCII letters are preserved and lowercased`() {
        var occ: [String: Int] = [:]
        // Cyrillic — Swifty Notes ships in Russian-speaking communities,
        // we need TOC navigation to keep working for native headings.
        #expect(HeadingSlug.slug("Привет Мир", occurrences: &occ) == "привет-мир")
        #expect(HeadingSlug.slug("Café & Crème", occurrences: &occ) == "café-crème")
    }

    @Test
    func `digits are kept as identifier characters`() {
        var occ: [String: Int] = [:]
        #expect(HeadingSlug.slug("Q3 2026 Roadmap", occurrences: &occ) == "q3-2026-roadmap")
    }

    @Test
    func `duplicate headings get -2, -3 suffixes in encounter order`() {
        var occ: [String: Int] = [:]
        #expect(HeadingSlug.slug("Goals", occurrences: &occ) == "goals")
        #expect(HeadingSlug.slug("Goals", occurrences: &occ) == "goals-2")
        #expect(HeadingSlug.slug("Goals", occurrences: &occ) == "goals-3")
        // A different heading keeps its own counter.
        #expect(HeadingSlug.slug("Non-goals", occurrences: &occ) == "non-goals")
        #expect(HeadingSlug.slug("Non-goals", occurrences: &occ) == "non-goals-2")
        // Original heading continues its own counter.
        #expect(HeadingSlug.slug("Goals", occurrences: &occ) == "goals-4")
    }

    @Test
    func `dedup compares against final slug, not raw text`() {
        var occ: [String: Int] = [:]
        // Two distinct strings that normalize to the same slug must still
        // collide — otherwise IDs are not stable for scroll-spy.
        #expect(HeadingSlug.slug("Hello World", occurrences: &occ) == "hello-world")
        #expect(HeadingSlug.slug("Hello, World!", occurrences: &occ) == "hello-world-2")
    }
}
