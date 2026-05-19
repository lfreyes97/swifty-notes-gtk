import Foundation
@testable import SwiftyNotes
import Testing

struct AppLaunchOptionsTests {
    @Test
    func `empty argument list yields default options`() {
        let opts = AppLaunchOptions.parse(arguments: [])
        #expect(!opts.forceUpdateAvailable)
        #expect(opts.passthroughArguments == [])
    }

    @Test
    func `recognizes --force-update-available flag and strips it`() {
        let opts = AppLaunchOptions.parse(arguments: ["--force-update-available"])
        #expect(opts.forceUpdateAvailable)
        #expect(opts.passthroughArguments == [])
    }

    @Test
    func `keeps other arguments untouched when stripping the flag`() {
        let opts = AppLaunchOptions.parse(arguments: ["--gtk-debug=warnings", "--force-update-available", "note.md"])
        #expect(opts.forceUpdateAvailable)
        #expect(opts.passthroughArguments == ["--gtk-debug=warnings", "note.md"])
    }

    @Test
    func `does not match unrelated --force prefix`() {
        let opts = AppLaunchOptions.parse(arguments: ["--force"])
        #expect(!opts.forceUpdateAvailable)
        #expect(opts.passthroughArguments == ["--force"])
    }
}
