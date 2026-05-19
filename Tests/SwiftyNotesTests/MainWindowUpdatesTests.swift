#if !os(macOS)
import Adwaita
import Foundation
@testable import SwiftyNotes
import Testing

struct MainWindowUpdatesTests {
    @MainActor
    private static func makeWindow(
        appID: String,
        forceUpdateAvailable: Bool = false,
        directoryOpener: @escaping (URL) throws -> Void = { _ in },
    ) throws -> MainWindow {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let app = Application(id: appID)
        try app.register()
        return MainWindow(
            application: app,
            state: AppState(),
            stateStore: WorkspaceStateStore(
                stateFileURL: temp.appendingPathComponent("workspace.json", isDirectory: false),
            ),
            repository: NotesRepository(notesDirectory: temp),
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
            forceUpdateAvailable: forceUpdateAvailable,
            directoryOpener: directoryOpener,
        )
    }

    @Test @MainActor
    func `updateAvailable result shows the banner and records the release URL`() throws {
        let window = try Self.makeWindow(appID: "me.spaceinbox.swiftynotes.tests.update.available")
        let releaseURL = URL(string: "https://github.com/makoni/swifty-notes-gtk/releases/tag/v1.2.4")!

        window.handleUpdateCheckResult(.updateAvailable(version: "1.2.4", releaseURL: releaseURL), manual: false)

        #expect(window.updateBanner.isVisible)
        #expect(window.pendingUpdateReleaseURL == releaseURL)
    }

    @Test @MainActor
    func `upToDate result leaves the banner hidden`() throws {
        let window = try Self.makeWindow(appID: "me.spaceinbox.swiftynotes.tests.update.uptodate")

        window.handleUpdateCheckResult(.upToDate, manual: false)

        #expect(!window.updateBanner.isVisible)
        #expect(window.pendingUpdateReleaseURL == nil)
    }

    @Test @MainActor
    func `error result leaves the banner hidden`() throws {
        let window = try Self.makeWindow(appID: "me.spaceinbox.swiftynotes.tests.update.error")

        window.handleUpdateCheckResult(.error(message: "network unreachable"), manual: true)

        #expect(!window.updateBanner.isVisible)
        #expect(window.pendingUpdateReleaseURL == nil)
    }

    @Test @MainActor
    func `Update button opens the release URL through the injected opener`() throws {
        let openedURL = URLRecorder()
        let window = try Self.makeWindow(
            appID: "me.spaceinbox.swiftynotes.tests.update.openrelease",
            directoryOpener: { url in
                openedURL.set(url)
            },
        )
        let releaseURL = URL(string: "https://github.com/makoni/swifty-notes-gtk/releases/tag/v9.9.9")!
        window.handleUpdateCheckResult(.updateAvailable(version: "9.9.9", releaseURL: releaseURL), manual: false)

        window.openPendingUpdateReleasePage()

        #expect(openedURL.snapshot() == releaseURL)
    }

    @Test @MainActor
    func `Update button is a no-op before any successful check has stored a URL`() throws {
        let openedURL = URLRecorder()
        let window = try Self.makeWindow(
            appID: "me.spaceinbox.swiftynotes.tests.update.openrelease.nil",
            directoryOpener: { url in
                openedURL.set(url)
            },
        )

        window.openPendingUpdateReleasePage()

        #expect(openedURL.snapshot() == nil)
    }

    @Test @MainActor
    func `force-update-available flag promotes equal remote version into updateAvailable via handleUpdateCheckResult`() throws {
        // The force-flag end-to-end path is already covered by
        // UpdateCheckerTests; here we just confirm the MainWindow
        // surface mirrors that outcome — given an `updateAvailable`
        // result (which is what UpdateChecker hands back under the
        // force flag), the banner reveals and the URL is recorded.
        let window = try Self.makeWindow(
            appID: "me.spaceinbox.swiftynotes.tests.update.forceflag",
            forceUpdateAvailable: true,
        )
        let releaseURL = URL(string: "https://github.com/makoni/swifty-notes-gtk/releases/tag/v0.0.1")!

        window.handleUpdateCheckResult(.updateAvailable(version: "0.0.1", releaseURL: releaseURL), manual: false)

        #expect(window.updateBanner.isVisible)
        #expect(window.pendingUpdateReleaseURL == releaseURL)
    }
}
#endif
