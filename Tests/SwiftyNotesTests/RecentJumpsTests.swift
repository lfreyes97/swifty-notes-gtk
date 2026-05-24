import Foundation
@testable import SwiftyNotes
import Testing

struct RecentJumpsTests {
    @Test
    func `starts empty`() {
        let jumps = RecentJumps()
        #expect(jumps.ids == [])
    }

    @Test
    func `record prepends new ids in newest-first order`() {
        var jumps = RecentJumps()
        jumps.record("a")
        jumps.record("b")
        jumps.record("c")
        #expect(jumps.ids == ["c", "b", "a"])
    }

    @Test
    func `recording an existing id moves it to the front without duplicating`() {
        var jumps = RecentJumps()
        jumps.record("a")
        jumps.record("b")
        jumps.record("c")
        jumps.record("a") // re-record
        #expect(jumps.ids == ["a", "c", "b"])
    }

    @Test
    func `recently-jumped list is capped at five entries`() {
        var jumps = RecentJumps()
        for id in ["a", "b", "c", "d", "e", "f", "g"] {
            jumps.record(id)
        }
        // Newest five, oldest two dropped.
        #expect(jumps.ids == ["g", "f", "e", "d", "c"])
    }

    @Test
    func `cap honors moves so the cap doesn't push the moved entry off`() {
        var jumps = RecentJumps(ids: ["a", "b", "c", "d", "e"])
        // Re-record "e" — should stay at the front, list unchanged length.
        jumps.record("e")
        #expect(jumps.ids == ["e", "a", "b", "c", "d"])
    }

    @Test
    func `seed initializer truncates to the cap`() {
        let jumps = RecentJumps(ids: ["a", "b", "c", "d", "e", "f", "g"])
        #expect(jumps.ids == ["a", "b", "c", "d", "e"])
    }

    @Test
    func `seed initializer dedupes preserving first occurrence`() {
        let jumps = RecentJumps(ids: ["a", "b", "a", "c", "b"])
        #expect(jumps.ids == ["a", "b", "c"])
    }
}
