#if !os(macOS)
import Adwaita
import Foundation
@testable import SwiftyNotes
import Testing

struct FindReplaceBarWidgetTests {
    @MainActor
    private static func makeBar(suffix: String) throws -> FindReplaceBar {
        let app = Application(id: "me.spaceinbox.swiftynotes.tests.findreplace.\(suffix)")
        try app.register()
        return FindReplaceBar()
    }

    @Test @MainActor
    func `bar starts hidden in find mode with no query`() throws {
        let bar = try Self.makeBar(suffix: "initial")
        #expect(bar.isVisible == false)
        #expect(bar.mode == .find)
        #expect(bar.query.isEmpty)
        #expect(bar.replacement.isEmpty)
        #expect(bar.options == SearchOptions())
    }

    @Test @MainActor
    func `setVisible true opens in the requested mode`() throws {
        let bar = try Self.makeBar(suffix: "open")
        bar.setVisible(true, mode: .find)
        #expect(bar.isVisible == true)
        #expect(bar.mode == .find)

        bar.setVisible(true, mode: .replace)
        #expect(bar.mode == .replace)
    }

    @Test @MainActor
    func `typing in the find entry fires onQueryChanged with current options`() throws {
        let bar = try Self.makeBar(suffix: "querychanged")
        var observed: [(String, SearchOptions)] = []
        bar.onQueryChanged = { query, options in
            observed.append((query, options))
        }
        bar.debugTypeQuery("hello")
        #expect(observed.last?.0 == "hello")
        #expect(observed.last?.1 == SearchOptions())
    }

    @Test @MainActor
    func `toggling case sensitivity flows through to options + re-fires query`() throws {
        let bar = try Self.makeBar(suffix: "casetoggle")
        bar.query = "term"
        var lastOptions: SearchOptions?
        bar.onQueryChanged = { _, options in
            lastOptions = options
        }
        bar.debugToggleCaseSensitive()
        #expect(bar.options.caseSensitive == true)
        #expect(lastOptions?.caseSensitive == true)
    }

    @Test @MainActor
    func `next + prev buttons fire their callbacks`() throws {
        let bar = try Self.makeBar(suffix: "step")
        var nextCount = 0
        var prevCount = 0
        bar.onStepNext = { nextCount += 1 }
        bar.onStepPrev = { prevCount += 1 }
        bar.debugClickNext()
        bar.debugClickPrev()
        #expect(nextCount == 1)
        #expect(prevCount == 1)
    }

    @Test @MainActor
    func `replace + replace-all buttons fire their callbacks in replace mode`() throws {
        let bar = try Self.makeBar(suffix: "replace")
        bar.setVisible(true, mode: .replace)
        var replaceOne = 0
        var replaceAll = 0
        bar.onReplaceOne = { replaceOne += 1 }
        bar.onReplaceAll = { replaceAll += 1 }
        bar.debugClickReplace()
        bar.debugClickReplaceAll()
        #expect(replaceOne == 1)
        #expect(replaceAll == 1)
    }

    @Test @MainActor
    func `read-only bar disables replace controls and never fires their callbacks`() throws {
        let bar = try Self.makeBar(suffix: "readonly")
        bar.isReadOnly = true
        bar.setVisible(true, mode: .replace)
        var replaceOne = 0
        bar.onReplaceOne = { replaceOne += 1 }
        bar.debugClickReplace()
        // Disabled buttons in GTK don't fire `clicked`, so the
        // callback should remain at zero.
        #expect(replaceOne == 0)
        #expect(bar.replaceButton.sensitive == false)
        #expect(bar.replaceAllButton.sensitive == false)
    }

    @Test @MainActor
    func `setMatchCount renders the standard "N of M" label`() throws {
        let bar = try Self.makeBar(suffix: "count")
        bar.setMatchCount(total: 0, activeDisplayIndex: nil)
        #expect(bar.countLabel.text.isEmpty)
        #expect(bar.countLabel.visible == false)

        bar.setMatchCount(total: 17, activeDisplayIndex: 3)
        #expect(bar.countLabel.text == "3 of 17")
        #expect(bar.countLabel.visible == true)

        // No active index — just total. Used when the controller has
        // counted matches but hasn't activated one yet.
        bar.setMatchCount(total: 5, activeDisplayIndex: nil)
        #expect(bar.countLabel.text == "5 matches")

        bar.setMatchCount(total: 1, activeDisplayIndex: nil)
        #expect(bar.countLabel.text == "1 match")
    }

    @Test @MainActor
    func `programmatic query setter does NOT fire onQueryChanged`() throws {
        let bar = try Self.makeBar(suffix: "programmatic")
        var fired = false
        bar.onQueryChanged = { _, _ in fired = true }
        bar.query = "programmed text"
        // Programmatic writes are intentionally silent so a
        // controller can pre-fill the field on Ctrl+F (e.g. with the
        // current selection) without immediately re-running search
        // on a phantom user-input event. `notifyQueryChanged()` is
        // the explicit opt-in.
        #expect(fired == false)
        bar.notifyQueryChanged()
        #expect(fired == true)
    }

    @Test @MainActor
    func `setVisible false fires onClose`() throws {
        let bar = try Self.makeBar(suffix: "close")
        bar.setVisible(true)
        var closed = false
        bar.onClose = { closed = true }
        bar.setVisible(false)
        #expect(closed == true)
    }
}
#endif
