#if os(macOS)
import Adwaita
import Foundation
@testable import SwiftyNotes
import XCTest

final class MainWindowCoreXCTests: XCTestCase {
    @MainActor func test_main_window_creates_initial_note_and_updates_preview() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let app = Application(id: "me.spaceinbox.swiftynotes.tests")
        try app.register()

        let window = MainWindow(
            application: app,
            state: AppState(),
            stateStore: WorkspaceStateStore(
                stateFileURL: temp.appendingPathComponent("workspace.json", isDirectory: false),
            ),
            repository: NotesRepository(notesDirectory: temp),
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
        )

        window.debugLoadInitialNotes()
        XCTAssertTrue(window.debugNotesCount == 3)
        XCTAssertTrue(window.debugSelectedNoteContent == MarkdownShowcaseSeed.content)
        XCTAssertTrue(window.debugPreviewText.contains("Markdown Showcase"))
        XCTAssertTrue(window.debugPreviewText.contains("screenshot-ready note"))
        XCTAssertTrue(window.debugPreviewText.contains("Feature Snapshot"))
        XCTAssertTrue(window.debugPreviewText.contains("Toolbar"))

        window.debugSetEditorText("# Title\n\nBody")
        XCTAssertTrue(window.debugSelectedNoteContent == "# Title\n\nBody")
        XCTAssertTrue(window.debugPreviewText.contains("Title"))
        XCTAssertTrue(window.debugPreviewText.contains("Body"))
    }

    @MainActor func test_main_window_selecting_CLI_seeded_note_updates_preview() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let app = Application(id: "me.spaceinbox.swiftynotes.tests.cliseedpreview")
        try app.register()

        let window = MainWindow(
            application: app,
            state: AppState(),
            stateStore: WorkspaceStateStore(
                stateFileURL: temp.appendingPathComponent("workspace.json", isDirectory: false),
            ),
            repository: NotesRepository(notesDirectory: temp),
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
        )

        window.debugLoadInitialNotes()
        // The seeded onboarding layout puts the explanatory guides
        // inside an expanded "Guides" folder so they appear first in
        // the sidebar, with the root-level showcase below them.
        XCTAssertTrue(window.debugDisplayedNoteTitles == [
            "About Swifty Notes",
            "Using Swifty Notes CLI",
            "Markdown Showcase",
        ])

        window.debugSelectDisplayedNote(at: 1)

        XCTAssertNotNil(window.debugSelectedNoteStableID())
        XCTAssertTrue(window.debugSelectedNoteContent == SwiftyNotesCLISeed.content)
        XCTAssertTrue(window.debugPreviewText.contains("Using Swifty Notes CLI"))
        XCTAssertTrue(window.debugPreviewText.contains("swiftynotes cli list"))
        XCTAssertTrue(window.debugPreviewText.contains("swiftynotes cli update"))
    }

    @MainActor func test_main_window_present_renders_preview_for_initially_selected_note() async throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let repository = NotesRepository(notesDirectory: temp)
        _ = try repository.createNote(initialContent: "# Initial\n\nPreview body")

        let app = Application(id: "me.spaceinbox.swiftynotes.tests.initialpreview")
        try app.register()

        let window = MainWindow(
            application: app,
            state: AppState(),
            stateStore: WorkspaceStateStore(
                stateFileURL: temp.appendingPathComponent("workspace.json", isDirectory: false),
            ),
            repository: repository,
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
        )

        window.present()
        try await Task.sleep(for: .milliseconds(40))

        XCTAssertTrue(window.debugSelectedNoteContent == "# Initial\n\nPreview body")
        XCTAssertTrue(window.debugPreviewText.contains("Initial"))
        XCTAssertTrue(window.debugPreviewText.contains("Preview body"))
    }

    @MainActor func test_main_window_applies_configured_editor_autosave_and_appearance_preferences_at_startup() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let app = Application(id: "me.spaceinbox.swiftynotes.tests.editorpreferences")
        try app.register()

        let originalScheme = StyleManager.default.colorScheme
        defer { StyleManager.default.colorScheme = originalScheme }

        let window = MainWindow(
            application: app,
            state: AppState(),
            stateStore: WorkspaceStateStore(
                stateFileURL: temp.appendingPathComponent("workspace.json", isDirectory: false),
            ),
            repository: NotesRepository(notesDirectory: temp),
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
            appSettings: AppSettings(
                wrapsEditorLines: false,
                editorFontSize: 18,
                editorTabWidth: 2,
                editorIndentStyle: .tabs,
                autosaveDelaySeconds: 5,
                appearanceMode: .dark,
            ),
        )

        XCTAssertTrue(window.debugEditorWrapsLines == false)
        XCTAssertTrue(window.debugEditorFontSize == 18)
        XCTAssertTrue(window.debugEditorTabWidth == 2)
        XCTAssertTrue(window.debugEditorInsertsSpacesInsteadOfTabs == false)
        XCTAssertTrue(window.debugAutosaveDelaySeconds == 5)
        XCTAssertTrue(window.debugAppearanceMode == .dark)
        XCTAssertTrue(StyleManager.default.colorScheme == .forceDark)
    }

    @MainActor func test_main_window_create_note_adds_another_note() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let app = Application(id: "me.spaceinbox.swiftynotes.tests.create")
        try app.register()

        let window = MainWindow(
            application: app,
            state: AppState(),
            stateStore: WorkspaceStateStore(
                stateFileURL: temp.appendingPathComponent("workspace.json", isDirectory: false),
            ),
            repository: NotesRepository(notesDirectory: temp),
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
        )

        window.debugLoadInitialNotes()
        XCTAssertTrue(window.debugNotesCount == 3)

        window.debugCreateNote()
        XCTAssertTrue(window.debugNotesCount == 4)
    }

    @MainActor func test_main_window_create_note_after_present_keeps_selection_stable() async throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let app = Application(id: "me.spaceinbox.swiftynotes.tests.createpresented")
        try app.register()

        let window = MainWindow(
            application: app,
            state: AppState(),
            stateStore: WorkspaceStateStore(
                stateFileURL: temp.appendingPathComponent("workspace.json", isDirectory: false),
            ),
            repository: NotesRepository(notesDirectory: temp),
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
        )

        window.present()
        try await Task.sleep(for: .milliseconds(40))

        window.debugCreateNote()
        try await Task.sleep(for: .milliseconds(40))

        XCTAssertTrue(window.debugNotesCount == 4)
        XCTAssertTrue(window.debugSelectedNoteContent == "")
        XCTAssertTrue(window.debugHeaderSubtitle.contains("Saved"))
    }

    @MainActor func test_main_window_imports_dropped_image_into_selected_note_assets_and_markdown() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let repository = NotesRepository(notesDirectory: temp)
        let existing = try repository.createNote(initialContent: "# Images\n\nBody")

        let app = Application(id: "me.spaceinbox.swiftynotes.tests.dropimage")
        try app.register()

        let window = MainWindow(
            application: app,
            state: AppState(),
            stateStore: WorkspaceStateStore(
                stateFileURL: temp.appendingPathComponent("workspace.json", isDirectory: false),
            ),
            repository: repository,
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
        )

        window.debugLoadInitialNotes()
        XCTAssertTrue(window.debugSelectedNoteStableID() == existing.stableID)

        let sourceImageURL = temp.appendingPathComponent("Dragged Diagram.PNG", isDirectory: false)
        try Data("dropped-image".utf8).write(to: sourceImageURL, options: .atomic)

        try window.importDroppedImages(from: [sourceImageURL])
        XCTAssertTrue(window.debugSelectedNoteContent?.contains("![Dragged Diagram](assets/dragged-diagram.png)") == true)

        window.saveSelectedNoteNow()
        let reloaded = try repository.loadNotes()
        XCTAssertTrue(reloaded[0].content.contains("![Dragged Diagram](assets/dragged-diagram.png)"))
        XCTAssertTrue(try Data(contentsOf: repository.noteAssetsDirectoryURL(for: reloaded[0]).appendingPathComponent("dragged-diagram.png")) == Data("dropped-image".utf8))
    }

    @MainActor func test_main_window_imports_pasted_image_into_selected_note_assets_and_markdown() throws {
        // Clipboard paste mirrors the drop-target import: the bytes the
        // clipboard handed us land in the note's `assets/` folder under
        // a unique `pasted.png` / `pasted-2.png` filename, and a
        // `![](path)` reference is inserted at the cursor. No alt text —
        // the clipboard never gives us a filename to lift one from.
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let repository = NotesRepository(notesDirectory: temp)
        let existing = try repository.createNote(initialContent: "# Pasted\n\nBody")

        let app = Application(id: "me.spaceinbox.swiftynotes.tests.paste-image")
        try app.register()

        let window = MainWindow(
            application: app,
            state: AppState(),
            stateStore: WorkspaceStateStore(
                stateFileURL: temp.appendingPathComponent("workspace.json", isDirectory: false),
            ),
            repository: repository,
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
        )

        window.debugLoadInitialNotes()
        XCTAssertTrue(window.debugSelectedNoteStableID() == existing.stableID)

        let pngBytes = Data("pasted-image".utf8)
        try window.importPastedImage(pngData: pngBytes)
        XCTAssertTrue(window.debugSelectedNoteContent?.contains("![](assets/pasted.png)") == true)

        // A second paste collides on filename and gets the standard `-2`
        // suffix, same as the URL-based drop-import path.
        try window.importPastedImage(pngData: Data("second-paste".utf8))
        XCTAssertTrue(window.debugSelectedNoteContent?.contains("![](assets/pasted-2.png)") == true)

        window.saveSelectedNoteNow()
        let reloaded = try repository.loadNotes()
        XCTAssertTrue(reloaded[0].content.contains("![](assets/pasted.png)"))
        XCTAssertTrue(reloaded[0].content.contains("![](assets/pasted-2.png)"))
        let assetsDir = repository.noteAssetsDirectoryURL(for: reloaded[0])
        XCTAssertTrue(try Data(contentsOf: assetsDir.appendingPathComponent("pasted.png")) == pngBytes)
        XCTAssertTrue(try Data(contentsOf: assetsDir.appendingPathComponent("pasted-2.png")) == Data("second-paste".utf8))
    }

    @MainActor func test_main_window_paste_URL_with_no_selection_wraps_it_as_a_markdown_link() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let repository = NotesRepository(notesDirectory: temp)
        _ = try repository.createNote(initialContent: "Cursor here: ")

        let app = Application(id: "me.spaceinbox.swiftynotes.tests.paste-url-bare")
        try app.register()

        let window = MainWindow(
            application: app,
            state: AppState(),
            stateStore: WorkspaceStateStore(
                stateFileURL: temp.appendingPathComponent("workspace.json", isDirectory: false),
            ),
            repository: repository,
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
        )

        window.debugLoadInitialNotes()
        window.debugSetEditorText("Cursor here: ")
        window.debugSelectEditorRange(13 ..< 13)

        window.handleClipboardTextPaste(
            clipboardText: "https://example.com",
            selectedText: "",
            textBefore: "Cursor here: ",
        )

        XCTAssertTrue(window.debugEditorText == "Cursor here: [https://example.com](https://example.com)")
    }

    @MainActor func test_main_window_paste_URL_with_selection_wraps_the_selection_as_link_text() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let repository = NotesRepository(notesDirectory: temp)
        _ = try repository.createNote(initialContent: "click here please")

        let app = Application(id: "me.spaceinbox.swiftynotes.tests.paste-url-selection")
        try app.register()

        let window = MainWindow(
            application: app,
            state: AppState(),
            stateStore: WorkspaceStateStore(
                stateFileURL: temp.appendingPathComponent("workspace.json", isDirectory: false),
            ),
            repository: repository,
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
        )

        window.debugLoadInitialNotes()
        window.debugSetEditorText("click here please")
        window.debugSelectEditorRange(0 ..< 10) // "click here"

        window.handleClipboardTextPaste(
            clipboardText: "https://example.com",
            selectedText: "click here",
            textBefore: "",
        )

        XCTAssertTrue(window.debugEditorText == "[click here](https://example.com) please")
    }

    @MainActor func test_main_window_paste_plain_text_inserts_text_without_wrapping() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let repository = NotesRepository(notesDirectory: temp)
        _ = try repository.createNote(initialContent: "")

        let app = Application(id: "me.spaceinbox.swiftynotes.tests.paste-plain")
        try app.register()

        let window = MainWindow(
            application: app,
            state: AppState(),
            stateStore: WorkspaceStateStore(
                stateFileURL: temp.appendingPathComponent("workspace.json", isDirectory: false),
            ),
            repository: repository,
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
        )

        window.debugLoadInitialNotes()
        window.debugSetEditorText("Prefix: ")
        window.debugSelectEditorRange(8 ..< 8)

        window.handleClipboardTextPaste(
            clipboardText: "just some words",
            selectedText: "",
            textBefore: "Prefix: ",
        )

        XCTAssertTrue(window.debugEditorText == "Prefix: just some words")
    }

    @MainActor func test_main_window_paste_URL_inside_code_block_keeps_URL_raw() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let repository = NotesRepository(notesDirectory: temp)
        _ = try repository.createNote(initialContent: "")

        let app = Application(id: "me.spaceinbox.swiftynotes.tests.paste-url-codeblock")
        try app.register()

        let window = MainWindow(
            application: app,
            state: AppState(),
            stateStore: WorkspaceStateStore(
                stateFileURL: temp.appendingPathComponent("workspace.json", isDirectory: false),
            ),
            repository: repository,
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
        )

        window.debugLoadInitialNotes()
        let prefix = "```\ncurl "
        window.debugSetEditorText(prefix)
        window.debugSelectEditorRange(prefix.count ..< prefix.count)

        window.handleClipboardTextPaste(
            clipboardText: "https://example.com",
            selectedText: "",
            textBefore: prefix,
        )

        XCTAssertTrue(window.debugEditorText == "```\ncurl https://example.com")
    }

    @MainActor func test_main_window_paste_image_throws_when_no_note_is_selected() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let app = Application(id: "me.spaceinbox.swiftynotes.tests.paste-image-no-note")
        try app.register()

        let window = MainWindow(
            application: app,
            state: AppState(),
            stateStore: WorkspaceStateStore(
                stateFileURL: temp.appendingPathComponent("workspace.json", isDirectory: false),
            ),
            repository: NotesRepository(notesDirectory: temp),
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
        )

        // Deliberately skip `debugLoadInitialNotes()` — no note selected.
        XCTAssertThrowsError(try window.importPastedImage(pngData: Data("any".utf8))) { error in
            XCTAssertTrue((error as? DroppedImageImportError) == .noSelectedNote)
        }
    }

    @MainActor func test_main_window_create_note_request_creates_note_after_main_loop_drain() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let deferredScheduler = TestMainActorScheduler()

        let app = Application(id: "me.spaceinbox.swiftynotes.tests.signal")
        try app.register()

        let window = MainWindow(
            application: app,
            state: AppState(),
            stateStore: WorkspaceStateStore(
                stateFileURL: temp.appendingPathComponent("workspace.json", isDirectory: false),
            ),
            repository: NotesRepository(notesDirectory: temp),
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
            deferredUIActionScheduler: deferredScheduler.schedule,
        )

        window.debugLoadInitialNotes()
        XCTAssertTrue(window.debugNotesCount == 3)

        window.debugRequestCreateNote()
        deferredScheduler.runPendingActions()
        XCTAssertTrue(window.debugNotesCount == 4)
    }

    @MainActor func test_main_window_deferred_selection_switch_runs_after_main_loop_drain() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let repository = NotesRepository(notesDirectory: temp)
        let first = Note(
            id: UUID(),
            filename: "first.md",
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 100),
            content: "# First\n\nOne",
        )
        let second = Note(
            id: UUID(),
            filename: "second.md",
            createdAt: Date(timeIntervalSince1970: 200),
            updatedAt: Date(timeIntervalSince1970: 200),
            content: "# Second\n\nTwo",
        )
        let savedFirst = try repository.save(note: first)
        let savedSecond = try repository.save(note: second)
        let deferredScheduler = TestMainActorScheduler()

        let app = Application(id: "me.spaceinbox.swiftynotes.tests.deferredselection")
        try app.register()

        let window = MainWindow(
            application: app,
            state: AppState(),
            stateStore: WorkspaceStateStore(
                stateFileURL: temp.appendingPathComponent("workspace.json", isDirectory: false),
            ),
            repository: repository,
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
            deferredUIActionScheduler: deferredScheduler.schedule,
        )

        window.debugLoadInitialNotes()

        XCTAssertTrue(window.debugSelectedNoteStableID() == savedSecond.stableID)

        window.debugRequestSelectDisplayedNote(at: 1)
        XCTAssertTrue(window.debugSelectedNoteStableID() == savedSecond.stableID)

        deferredScheduler.runPendingActions()
        XCTAssertTrue(window.debugSelectedNoteStableID() == savedFirst.stableID)
        XCTAssertTrue(window.debugPreviewText.contains("First"))
        XCTAssertTrue(window.debugPreviewText.contains("One"))
    }

    @MainActor func test_main_window_toolbar_buttons_expose_standard_tooltips() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let app = Application(id: "me.spaceinbox.swiftynotes.tests.tooltips")
        try app.register()

        let window = MainWindow(
            application: app,
            state: AppState(),
            stateStore: WorkspaceStateStore(
                stateFileURL: temp.appendingPathComponent("workspace.json", isDirectory: false),
            ),
            repository: NotesRepository(notesDirectory: temp),
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
        )

        window.debugLoadInitialNotes()
        XCTAssertTrue(window.debugToolbarTooltips["sidebar"] == "Hide Notes Sidebar")
        XCTAssertTrue(window.debugToolbarTooltips["new"] == "New Note")
        XCTAssertTrue(window.debugToolbarTooltips["save"] == "Save Note")
        XCTAssertTrue(window.debugToolbarTooltips["delete"] == "Delete Note")
        XCTAssertTrue(window.debugToolbarTooltips["menu"] == "Main Menu")
        XCTAssertTrue(window.debugToolbarTooltips["editorMode"] == "Editor only")
        XCTAssertTrue(window.debugToolbarTooltips["splitMode"] == "Split view")
        XCTAssertTrue(window.debugToolbarTooltips["previewMode"] == "Preview only")
        XCTAssertTrue(window.debugToolbarTooltips["formatHeading"] == "Turn the current line into a heading")
        XCTAssertTrue(window.debugToolbarTooltips["formatBold"] == "Wrap the selection in bold markdown")
        XCTAssertTrue(window.debugToolbarTooltips["formatItalic"] == "Wrap the selection in italic markdown")
        XCTAssertTrue(window.debugToolbarTooltips["formatCode"] == "Insert inline code or a fenced code block")
        XCTAssertTrue(window.debugToolbarTooltips["formatLink"] == "Insert a markdown link")
        XCTAssertTrue(window.debugToolbarTooltips["formatQuote"] == "Prefix the selected lines as a quote")
        XCTAssertTrue(window.debugToolbarTooltips["formatBullet"] == "Prefix the selected lines as a bulleted list")
        XCTAssertTrue(window.debugToolbarTooltips["formatNumbered"] == "Prefix the selected lines as a numbered list")
        XCTAssertTrue(window.debugToolbarTooltips["formatTask"] == "Prefix the selected lines as a task list")
    }

    @MainActor func test_main_window_formatting_toolbar_uses_compact_icon_mode_when_editor_narrows() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let app = Application(id: "me.spaceinbox.swiftynotes.tests.toolbarcompact")
        try app.register()

        let window = MainWindow(
            application: app,
            state: AppState(),
            stateStore: WorkspaceStateStore(
                stateFileURL: temp.appendingPathComponent("workspace.json", isDirectory: false),
            ),
            repository: NotesRepository(notesDirectory: temp),
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
        )

        window.debugLoadInitialNotes()
        let wideEnough = window.debugEditorFormattingToolbarCompactThreshold + 80
        let tooNarrow = window.debugEditorFormattingToolbarCompactThreshold - 1
        window.debugSetEditorFormattingToolbarWidth(wideEnough)

        let expandedLabels: [MarkdownFormattingAction: String?] = [
            .heading: "H1",
            .bold: "Bold",
            .italic: "Italic",
            .code: "</>",
            .link: "Link",
            .quote: "Quote",
            .bulletList: "Bullets",
            .numberedList: "1.",
            .taskList: "[ ]",
            .table: "Table",
        ]
        XCTAssertTrue(window.debugEditorFormattingToolbarSnapshot == .init(
            isCompact: false,
            usesTwoRows: false,
            labelsByAction: expandedLabels,
        ))

        window.debugSetEditorFormattingToolbarWidth(tooNarrow)

        let compactLabels: [MarkdownFormattingAction: String?] = [
            .heading: "H1",
            .bold: nil,
            .italic: nil,
            .code: "</>",
            .link: nil,
            .quote: nil,
            .bulletList: nil,
            .numberedList: nil,
            .taskList: "[ ]",
            .table: nil,
        ]
        XCTAssertTrue(window.debugEditorFormattingToolbarSnapshot == .init(
            isCompact: true,
            usesTwoRows: false,
            labelsByAction: compactLabels,
        ))
        XCTAssertTrue(window.debugToolbarTooltips["formatBold"] == "Wrap the selection in bold markdown")

        window.debugSetEditorFormattingToolbarWidth(wideEnough)

        XCTAssertTrue(window.debugEditorFormattingToolbarSnapshot == .init(
            isCompact: false,
            usesTwoRows: false,
            labelsByAction: expandedLabels,
        ))
    }

    @MainActor func test_main_window_formatting_toolbar_wraps_into_two_rows_when_compact_row_still_does_not_fit() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let app = Application(id: "me.spaceinbox.swiftynotes.tests.toolbarwrap")
        try app.register()

        let window = MainWindow(
            application: app,
            state: AppState(),
            stateStore: WorkspaceStateStore(
                stateFileURL: temp.appendingPathComponent("workspace.json", isDirectory: false),
            ),
            repository: NotesRepository(notesDirectory: temp),
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
        )

        window.debugLoadInitialNotes()
        window.debugSetEditorFormattingToolbarWidth(220)

        let compactLabels: [MarkdownFormattingAction: String?] = [
            .heading: "H1",
            .bold: nil,
            .italic: nil,
            .code: "</>",
            .link: nil,
            .quote: nil,
            .bulletList: nil,
            .numberedList: nil,
            .taskList: "[ ]",
            .table: nil,
        ]
        XCTAssertTrue(window.debugEditorFormattingToolbarSnapshot == .init(
            isCompact: true,
            usesTwoRows: true,
            labelsByAction: compactLabels,
        ))
        XCTAssertTrue(window.debugToolbarTooltips["formatNumbered"] == "Prefix the selected lines as a numbered list")

        window.debugSetEditorFormattingToolbarWidth(window.debugEditorFormattingToolbarCompactThreshold - 1)

        XCTAssertTrue(window.debugEditorFormattingToolbarSnapshot == .init(
            isCompact: true,
            usesTwoRows: false,
            labelsByAction: compactLabels,
        ))
    }

    @MainActor func test_main_window_uses_application_icon_name() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let app = Application(id: "me.spaceinbox.swiftynotes.tests.windowicon")
        try app.register()

        let window = MainWindow(
            application: app,
            state: AppState(),
            stateStore: WorkspaceStateStore(
                stateFileURL: temp.appendingPathComponent("workspace.json", isDirectory: false),
            ),
            repository: NotesRepository(notesDirectory: temp),
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
        )

        XCTAssertTrue(window.debugWindowIconName == AppIdentity.identifier)
    }

    @MainActor func test_main_window_sidebar_toggle_hides_and_shows_sidebar() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let app = Application(id: "me.spaceinbox.swiftynotes.tests.sidebartoggle")
        try app.register()

        let window = MainWindow(
            application: app,
            state: AppState(),
            stateStore: WorkspaceStateStore(
                stateFileURL: temp.appendingPathComponent("workspace.json", isDirectory: false),
            ),
            repository: NotesRepository(notesDirectory: temp),
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
        )

        window.debugLoadInitialNotes()
        XCTAssertTrue(window.debugSidebarVisible)
        XCTAssertTrue(window.debugToolbarTooltips["sidebar"] == "Hide Notes Sidebar")

        window.debugEmitSidebarToggleClicked()
        XCTAssertFalse(window.debugSidebarVisible)
        XCTAssertTrue(window.debugToolbarTooltips["sidebar"] == "Show Notes Sidebar")

        window.debugEmitSidebarToggleClicked()
        XCTAssertTrue(window.debugSidebarVisible)
        XCTAssertTrue(window.debugToolbarTooltips["sidebar"] == "Hide Notes Sidebar")
    }

    @MainActor func test_main_window_search_entry_filters_displayed_notes_and_persists_query() async throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let stateFileURL = temp.appendingPathComponent("workspace.json", isDirectory: false)
        let repository = NotesRepository(notesDirectory: temp)
        _ = try repository.createNote(initialContent: "# Alpha\n\nFirst")
        try await Task.sleep(for: .milliseconds(20))
        _ = try repository.createNote(initialContent: "# Beta\n\nSecond")

        let stateStore = WorkspaceStateStore(stateFileURL: stateFileURL)
        let app = Application(id: "me.spaceinbox.swiftynotes.tests.search")
        try app.register()

        let window = MainWindow(
            application: app,
            state: AppState(),
            stateStore: stateStore,
            repository: repository,
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
        )

        window.debugLoadInitialNotes()
        XCTAssertTrue(window.debugDisplayedNoteTitles == ["Beta", "Alpha"])

        window.debugSetSearchQuery("alp")

        XCTAssertTrue(window.debugSearchQuery == "alp")
        XCTAssertTrue(window.debugDisplayedNotesCount == 1)
        XCTAssertTrue(window.debugDisplayedNoteTitles == ["Alpha"])
        XCTAssertTrue(try stateStore.load().searchQuery == "alp")
    }

    @MainActor func test_main_window_view_mode_switcher_updates_layout() async throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let app = Application(id: "me.spaceinbox.swiftynotes.tests.previewpane")
        try app.register()

        let window = MainWindow(
            application: app,
            state: AppState(),
            stateStore: WorkspaceStateStore(
                stateFileURL: temp.appendingPathComponent("workspace.json", isDirectory: false),
            ),
            repository: NotesRepository(notesDirectory: temp),
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
        )

        window.debugLoadInitialNotes()
        XCTAssertTrue(window.debugIsPreviewPaneAttached)
        XCTAssertTrue(window.debugViewMode == .split)

        window.debugSelectViewMode(.editor)
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertFalse(window.debugIsPreviewPaneAttached)
        XCTAssertTrue(window.debugViewMode == .editor)

        window.debugSelectViewMode(.preview)
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertFalse(window.debugIsPreviewPaneAttached)
        XCTAssertTrue(window.debugViewMode == .preview)

        window.debugSelectViewMode(.split)
        XCTAssertTrue(window.debugIsPreviewPaneAttached)
        XCTAssertTrue(window.debugViewMode == .split)
    }

    @MainActor func test_main_window_formatting_toolbar_applies_bold_to_selected_editor_text() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let app = Application(id: "me.spaceinbox.swiftynotes.tests.formatting")
        try app.register()

        let window = MainWindow(
            application: app,
            state: AppState(),
            stateStore: WorkspaceStateStore(
                stateFileURL: temp.appendingPathComponent("workspace.json", isDirectory: false),
            ),
            repository: NotesRepository(notesDirectory: temp),
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
        )

        window.debugLoadInitialNotes()
        window.debugSetEditorText("Hello world")
        window.debugSelectEditorRange(6 ..< 11)

        window.debugEmitEditorFormattingButtonClicked(.bold)

        XCTAssertTrue(window.debugEditorText == "Hello **world**")
        XCTAssertTrue(window.debugSelectedNoteContent == "Hello **world**")
        XCTAssertTrue(window.debugEditorSelectionRange == 6 ..< 15)
    }

    @MainActor func test_main_window_formatting_toolbar_remembers_last_chosen_table_size_and_alignments() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let stateURL = temp.appendingPathComponent("workspace.json", isDirectory: false)
        let store = WorkspaceStateStore(stateFileURL: stateURL)

        let app = Application(id: "me.spaceinbox.swiftynotes.tests.formattingremembertable")
        try app.register()

        let window = MainWindow(
            application: app,
            state: AppState(),
            stateStore: store,
            repository: NotesRepository(notesDirectory: temp),
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
        )

        window.debugLoadInitialNotes()
        window.debugSetEditorText("")
        window.debugSelectEditorRange(0 ..< 0)

        window.debugPickTableSize(rows: 3, cols: 2, alignments: [.right, .center])

        let persisted = try store.load()
        XCTAssertTrue(persisted.lastTableRows == 3)
        XCTAssertTrue(persisted.lastTableCols == 2)
        XCTAssertTrue(persisted.lastTableAlignments == [.right, .center])
        XCTAssertTrue(window.debugEditorText.contains("| Column 1 | Column 2 |"))
        XCTAssertTrue(window.debugEditorText.contains("| -------: | :------: |"))
    }

    @MainActor func test_main_window_formatting_toolbar_insert_table_writes_scaffold_at_the_cursor_and_selects_the_first_header_cell() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let app = Application(id: "me.spaceinbox.swiftynotes.tests.formattinginsert-table")
        try app.register()

        let window = MainWindow(
            application: app,
            state: AppState(),
            stateStore: WorkspaceStateStore(
                stateFileURL: temp.appendingPathComponent("workspace.json", isDirectory: false),
            ),
            repository: NotesRepository(notesDirectory: temp),
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
        )

        window.debugLoadInitialNotes()
        window.debugSetEditorText("")
        window.debugSelectEditorRange(0 ..< 0)

        window.debugPickTableSize(rows: 2, cols: 3)

        // Confirming the alignment phase writes explicit per-column markers.
        // Default alignment is left, so the post-header row picks up `:---`.
        let expected = """
        | Column 1 | Column 2 | Column 3 |
        | :------- | :------- | :------- |
        |          |          |          |
        |          |          |          |
        """ + "\n"
        XCTAssertTrue(window.debugEditorText == expected)
        XCTAssertTrue(window.debugSelectedNoteContent == expected)
        // "Column 1" is selected so the user can start typing straight away.
        let selection = window.debugEditorSelectionRange
        let headerStart = try expected.distance(
            from: expected.startIndex,
            to: XCTUnwrap(expected.range(of: "Column 1")?.lowerBound),
        )
        XCTAssertTrue(selection == headerStart ..< (headerStart + "Column 1".count))
    }

    @MainActor func test_main_window_formatting_toolbar_toggles_bold_off_for_formatted_selection() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let app = Application(id: "me.spaceinbox.swiftynotes.tests.formattingtoggle")
        try app.register()

        let window = MainWindow(
            application: app,
            state: AppState(),
            stateStore: WorkspaceStateStore(
                stateFileURL: temp.appendingPathComponent("workspace.json", isDirectory: false),
            ),
            repository: NotesRepository(notesDirectory: temp),
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
        )

        window.debugLoadInitialNotes()
        window.debugSetEditorText("Hello **world**")
        window.debugSelectEditorRange(6 ..< 15)

        window.debugEmitEditorFormattingButtonClicked(.bold)

        XCTAssertTrue(window.debugEditorText == "Hello world")
        XCTAssertTrue(window.debugSelectedNoteContent == "Hello world")
        XCTAssertTrue(window.debugEditorSelectionRange == 6 ..< 11)
    }

    @MainActor func test_main_window_formatting_toolbar_toggles_task_list_at_cursor_across_whole_line() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let app = Application(id: "me.spaceinbox.swiftynotes.tests.tasktoggle")
        try app.register()

        let window = MainWindow(
            application: app,
            state: AppState(),
            stateStore: WorkspaceStateStore(
                stateFileURL: temp.appendingPathComponent("workspace.json", isDirectory: false),
            ),
            repository: NotesRepository(notesDirectory: temp),
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
        )

        window.debugLoadInitialNotes()
        window.debugSetEditorText("- Ship it")
        window.debugSelectEditorRange(4 ..< 4)

        window.debugEmitEditorFormattingButtonClicked(.taskList)
        XCTAssertTrue(window.debugEditorText == "- [ ] Ship it")
        XCTAssertTrue(window.debugEditorSelectionRange == 0 ..< 13)

        window.debugEmitEditorFormattingButtonClicked(.taskList)
        XCTAssertTrue(window.debugEditorText == "Ship it")
        XCTAssertTrue(window.debugEditorSelectionRange == 0 ..< 7)
    }

    @MainActor func test_main_window_restores_persisted_workspace_state_for_filtering_and_visibility() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let repository = NotesRepository(notesDirectory: temp)
        let alpha = try repository.createNote(initialContent: "# Alpha\n\nFirst")
        _ = try repository.createNote(initialContent: "# Beta\n\nSecond")

        let persisted = WorkspaceState(
            selectedNoteID: alpha.id,
            isSidebarVisible: false,
            isPreviewVisible: false,
            searchQuery: "a",
            sortMode: .title,
            windowWidth: 980,
            windowHeight: 720,
            previewWidth: 620,
        )
        let app = Application(id: "me.spaceinbox.swiftynotes.tests.restorestate")
        try app.register()

        let window = MainWindow(
            application: app,
            state: AppState(persistedState: persisted),
            stateStore: WorkspaceStateStore(
                stateFileURL: temp.appendingPathComponent("workspace.json", isDirectory: false),
            ),
            repository: repository,
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
        )

        window.debugLoadInitialNotes()

        XCTAssertFalse(window.debugSidebarVisible)
        XCTAssertFalse(window.debugIsPreviewPaneAttached)
        XCTAssertTrue(window.debugViewMode == .editor)
        XCTAssertTrue(window.debugSearchQuery == "a")
        XCTAssertTrue(window.debugSortMode == .title)
        XCTAssertTrue(window.debugDisplayedNoteTitles == ["Alpha", "Beta"])
    }

    @MainActor func test_main_window_save_button_persists_current_editor_text() async throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let repository = NotesRepository(notesDirectory: temp)
        let app = Application(id: "me.spaceinbox.swiftynotes.tests.savebutton")
        try app.register()

        let window = MainWindow(
            application: app,
            state: AppState(),
            stateStore: WorkspaceStateStore(
                stateFileURL: temp.appendingPathComponent("workspace.json", isDirectory: false),
            ),
            repository: repository,
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
            autosaveDelay: .seconds(2),
        )

        window.debugLoadInitialNotes()
        window.debugSetEditorText("# Saved Title\n\nSaved body")
        XCTAssertTrue(window.debugEditorModified)

        window.debugEmitSaveClicked()
        try await Task.sleep(for: .milliseconds(80))

        let saved = try repository.loadNotes()
        XCTAssertTrue(saved.count == 3)
        XCTAssertTrue(saved[0].content == "# Saved Title\n\nSaved body")
        XCTAssertTrue(saved[0].title == "Saved Title")
        XCTAssertFalse(window.debugEditorModified)
        // The seeded "Guides" folder is expanded by default, so its
        // children (About / CLI guide) sort above root-level notes
        // in the sidebar; assert presence rather than first-position.
        XCTAssertTrue(window.debugDisplayedNoteTitles.contains("Saved Title"))
    }

    @MainActor func test_main_window_autosave_waits_for_last_edit_before_saving() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let repository = NotesRepository(notesDirectory: temp)
        let autosaveScheduler = TestMainActorScheduler()
        let app = Application(id: "me.spaceinbox.swiftynotes.tests.autosave")
        try app.register()

        let window = MainWindow(
            application: app,
            state: AppState(),
            stateStore: WorkspaceStateStore(
                stateFileURL: temp.appendingPathComponent("workspace.json", isDirectory: false),
            ),
            repository: repository,
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(taskScheduler: autosaveScheduler.schedule(after:operation:)),
            autosaveDelay: .milliseconds(40),
        )

        window.debugLoadInitialNotes()
        let originalContent = try repository.loadNotes()[0].content

        window.debugSetEditorText("# First draft\n\nA")
        XCTAssertTrue(window.debugHeaderSubtitle.contains("Unsaved changes"))
        XCTAssertTrue(try repository.loadNotes()[0].content == originalContent)

        window.debugSetEditorText("# Final draft\n\nB")
        XCTAssertTrue(window.debugHeaderSubtitle.contains("Unsaved changes"))
        XCTAssertTrue(try repository.loadNotes()[0].content == originalContent)

        autosaveScheduler.runPendingActions()
        let autosaved = try repository.loadNotes()
        XCTAssertTrue(autosaved[0].content == "# Final draft\n\nB")
        XCTAssertTrue(autosaved[0].title == "Final draft")
        XCTAssertFalse(window.debugEditorModified)
        XCTAssertTrue(window.debugHeaderSubtitle.contains("Saved"))
        XCTAssertTrue(!window.debugHeaderSubtitle.contains("Unsaved changes"))
    }

    @MainActor func test_main_window_reloads_external_create_after_poll() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let repository = NotesRepository(notesDirectory: temp)
        let externalRepository = NotesRepository(notesDirectory: temp)

        let app = Application(id: "me.spaceinbox.swiftynotes.tests.externalcreate")
        try app.register()

        let window = MainWindow(
            application: app,
            state: AppState(),
            stateStore: WorkspaceStateStore(
                stateFileURL: temp.appendingPathComponent("workspace.json", isDirectory: false),
            ),
            repository: repository,
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
        )

        window.debugLoadInitialNotes()
        XCTAssertTrue(window.debugNotesCount == 3)

        _ = try externalRepository.createNote(initialContent: "# External\n\nCreated from CLI")
        window.debugPollForExternalChanges()

        XCTAssertTrue(window.debugNotesCount == 4)
        XCTAssertTrue(window.debugDisplayedNotesCount == 4)
    }

    @MainActor func test_main_window_reloads_external_update_after_poll() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let repository = NotesRepository(notesDirectory: temp)
        let original = try repository.createNote(initialContent: "# Original\n\nBody")
        let externalRepository = NotesRepository(notesDirectory: temp)

        let app = Application(id: "me.spaceinbox.swiftynotes.tests.externalupdate")
        try app.register()

        let window = MainWindow(
            application: app,
            state: AppState(),
            stateStore: WorkspaceStateStore(
                stateFileURL: temp.appendingPathComponent("workspace.json", isDirectory: false),
            ),
            repository: repository,
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
        )

        window.debugLoadInitialNotes()
        XCTAssertTrue(window.debugNotesCount == 1)
        XCTAssertTrue(window.debugSelectedNoteContent == original.content)

        var externallyUpdated = try externalRepository.loadNotes().first
        XCTAssertNotNil(externallyUpdated)
        externallyUpdated?.content = "# Updated\n\nFresh text"
        _ = try externalRepository.save(note: XCTUnwrap(externallyUpdated))

        window.debugPollForExternalChanges()

        XCTAssertTrue(window.debugSelectedNoteContent == "# Updated\n\nFresh text")
        XCTAssertTrue(window.debugPreviewText.contains("Updated"))
        XCTAssertTrue(window.debugPreviewText.contains("Fresh text"))
    }
}
#endif
