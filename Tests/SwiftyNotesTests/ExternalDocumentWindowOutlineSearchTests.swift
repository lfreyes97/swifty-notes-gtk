#if !os(macOS)
import Adwaita
import Foundation
@testable import SwiftyNotes
import Testing

/// Outline + Find/Replace inside the standalone document window (#25
/// follow-up): users who open .md files directly — never the notes
/// library — get the same F9 outline and Ctrl+F/Ctrl+H search the main
/// window has.
struct ExternalDocumentWindowOutlineSearchTests {
    @MainActor
    private static func makeWindow(
        appID: String,
        content: String = "# Doc\n\n## Overview\n\nBody.\n\n## Features\n\nMore.",
    ) throws -> (window: ExternalDocumentWindow, fileURL: URL) {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        let fileURL = temp.appendingPathComponent("Standalone.md", isDirectory: false)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let app = Application(id: appID)
        try app.register()
        let window = try ExternalDocumentWindow(
            application: app,
            fileURL: fileURL,
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
        )
        window.present()
        return (window, fileURL)
    }

    @Test("Outline is populated with the document's headings after the preview flush") @MainActor
    func outlinePopulatesHeadingsAfterPreviewFlush() throws {
        let (window, _) = try Self.makeWindow(appID: "me.spaceinbox.swiftynotes.tests.extdoc.outline")
        // Force the deferred preview build the same way the outline tests
        // for the main window do — the outline refresh rides that flush.
        _ = window.debugPreviewText

        let headings = window.outlineSidebar.renderedHeadings
        #expect(headings.map(\.id) == ["doc", "overview", "features"])
        #expect(headings.map(\.level) == [1, 2, 2])
    }

    @Test("Outline panel starts hidden and F9 toggling flips the split view") @MainActor
    func outlineStartsHiddenAndToggles() throws {
        let (window, _) = try Self.makeWindow(appID: "me.spaceinbox.swiftynotes.tests.extdoc.toggle")

        #expect(window.isOutlineVisible == false)
        #expect(window.outlineSplitView.showSidebar == false)

        window.toggleOutlineVisibility()
        #expect(window.isOutlineVisible == true)
        #expect(window.outlineSplitView.showSidebar == true)

        window.toggleOutlineVisibility()
        #expect(window.isOutlineVisible == false)
        #expect(window.outlineSplitView.showSidebar == false)
    }

    @Test("Editing the document refreshes the outline headings") @MainActor
    func editingRefreshesOutline() throws {
        let (window, _) = try Self.makeWindow(appID: "me.spaceinbox.swiftynotes.tests.extdoc.refresh")
        _ = window.debugPreviewText

        window.debugSetEditorText("# Rewritten\n\n## Only Section\n\nText.")
        _ = window.debugPreviewText

        let headings = window.outlineSidebar.renderedHeadings
        #expect(headings.map(\.id) == ["rewritten", "only-section"])
    }

    @Test("Ctrl+F opens the editor find bar and wires the search controller") @MainActor
    func findOpensEditorBar() throws {
        let (window, _) = try Self.makeWindow(appID: "me.spaceinbox.swiftynotes.tests.extdoc.find")
        _ = window.debugPreviewText

        window.openFindBar(mode: .find)

        #expect(window.findReplaceBar.isVisible)
        #expect(window.editorSearchController != nil)
        #expect(!window.previewFindReplaceBar.isVisible)
    }

    @Test("Ctrl+F in preview-only mode opens the preview find bar") @MainActor
    func findInPreviewModeOpensPreviewBar() throws {
        let (window, _) = try Self.makeWindow(appID: "me.spaceinbox.swiftynotes.tests.extdoc.previewfind")
        _ = window.debugPreviewText
        // Real transition (reparents panes, rebinds the scroll spy) —
        // not a raw property write, so the layout half is covered too.
        window.debugSetViewMode(.preview)

        window.openFindBar(mode: .find)

        #expect(window.previewFindReplaceBar.isVisible)
        #expect(window.previewSearchController != nil)
        #expect(!window.findReplaceBar.isVisible)
        // The bar must be anchored in the visible widget tree, not a
        // detached orphan that merely flipped its own flag.
        #expect(window.previewFindReplaceBar.root.root != nil)
    }

    @Test("Ctrl+H opens the editor bar in replace mode even from preview mode") @MainActor
    func replaceAlwaysTargetsEditor() throws {
        let (window, _) = try Self.makeWindow(appID: "me.spaceinbox.swiftynotes.tests.extdoc.replace")
        _ = window.debugPreviewText
        window.debugSetViewMode(.preview)

        window.openFindBar(mode: .replace)

        #expect(window.findReplaceBar.isVisible)
        #expect(window.findReplaceBar.mode == .replace)
        #expect(!window.previewFindReplaceBar.isVisible)
    }

    @Test("Editing while the preview find bar is open recomputes its highlights") @MainActor
    func editingRecomputesPreviewSearch() throws {
        let (window, _) = try Self.makeWindow(
            appID: "me.spaceinbox.swiftynotes.tests.extdoc.research",
            content: "# Doc\n\nfindme once here",
        )
        _ = window.debugPreviewText
        window.debugSetViewMode(.preview)
        window.openFindBar(mode: .find)
        window.previewFindReplaceBar.query = "findme"
        window.previewFindReplaceBar.notifyQueryChanged()
        #expect(window.preview.debugAppliedHighlightTexts == ["findme"])

        // A second occurrence appears; the re-render must refresh the
        // match cache (renderPreviewNow → onPreviewRerendered).
        window.debugSetEditorText("# Doc\n\nfindme once here and findme twice")
        _ = window.debugPreviewText

        #expect(window.preview.debugAppliedHighlightTexts == ["findme", "findme"])
    }

    @Test("Buffer selection offsets slice by unicode scalars, not graphemes") @MainActor
    func selectionSubstringUsesScalarOffsets() throws {
        // GtkTextIter offsets count scalars: 🇷🇺 is one Character but
        // two scalars. A grapheme-based slice would drift past the flag
        // and prefill garbage.
        let text = "🇷🇺 target here"
        // Scalars: [🇷,🇺, space, t..t] — "target" spans scalar offsets 3..<9.
        #expect(FindReplaceCoordinator.substring(of: text, scalarOffsets: 3..<9) == "target")
        // Out-of-bounds degrades to nil, never traps.
        #expect(FindReplaceCoordinator.substring(of: text, scalarOffsets: 3..<99) == nil)
    }

    @Test("Quick jump palette opens with headings and picking one closes it") @MainActor
    func quickJumpOpensWithHeadings() throws {
        let (window, _) = try Self.makeWindow(appID: "me.spaceinbox.swiftynotes.tests.extdoc.palette")
        _ = window.debugPreviewText

        window.openCommandPalette()
        #expect(window.activeCommandPalette != nil)

        // Picking the highlighted heading exercises the onPick → scroll
        // path and closes the palette through onClosed.
        window.activeCommandPalette?.debugActivateHighlighted()
        #expect(window.activeCommandPalette == nil)
    }

    @Test("Quick jump palette does not open for a document without headings") @MainActor
    func quickJumpNoHeadingsNoPalette() throws {
        let (window, _) = try Self.makeWindow(
            appID: "me.spaceinbox.swiftynotes.tests.extdoc.nopalette",
            content: "plain text without any headings",
        )
        _ = window.debugPreviewText

        window.openCommandPalette()
        #expect(window.activeCommandPalette == nil)
    }

    @Test("Runtime settings apply outline tweaks to the standalone window's sidebar") @MainActor
    func runtimeSettingsApplyOutlineTweaks() throws {
        let (window, _) = try Self.makeWindow(appID: "me.spaceinbox.swiftynotes.tests.extdoc.tweaks")

        // Density is the observable half of applyTweaks (the compact CSS
        // class on the sidebar root); tree-lines/drag-handles flow through
        // the same call into the private render state.
        window.applyRuntimeSettings(
            AppSettings(outlineDensity: .compact, outlineTreeLines: false, outlineDragHandles: false),
            shouldRefreshPreview: false,
        )
        #expect(window.outlineSidebar.root.hasCSSClass("outline-compact"))

        window.applyRuntimeSettings(
            AppSettings(outlineDensity: .comfortable),
            shouldRefreshPreview: false,
        )
        #expect(!window.outlineSidebar.root.hasCSSClass("outline-compact"))
    }
}
#endif
