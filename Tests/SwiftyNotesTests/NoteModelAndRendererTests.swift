import Adwaita
import Foundation
@testable import SwiftyNotes
import Testing

struct NoteModelAndRendererTests {
    @Test
    func `derived title uses first meaningful line`() {
        let title = Note.derivedTitle(from: "\n\n# Hello world\nBody")
        #expect(title == "Hello world")
    }

    @Test
    func `derived title skips leading standalone image`() {
        let title = Note.derivedTitle(from: "![Cover](assets/cover.png)\n\n# Hello world\nBody")
        #expect(title == "Hello world")
    }

    @Test
    func `derived title falls back for empty note`() {
        #expect(Note.derivedTitle(from: " \n\n ") == "New Note")
    }

    @Test
    func `note retitle replaces first meaningful line`() {
        let note = Note(
            id: UUID(),
            filename: "note.md",
            createdAt: Date(),
            updatedAt: Date(),
            content: "Shopping list\n- eggs",
        )

        let renamed = note.retitled("Groceries")
        #expect(renamed.title == "Groceries")
        #expect(renamed.content.hasPrefix("Groceries"))
    }

    @Test
    func `note retitle preserves leading image and replaces heading after it`() {
        let note = Note(
            id: UUID(),
            filename: "note.md",
            createdAt: Date(),
            updatedAt: Date(),
            content: "![Cover](assets/cover.png)\n\n# Original\n\nBody",
        )

        let renamed = note.retitled("Updated")
        #expect(renamed.title == "Updated")
        #expect(renamed.content == "![Cover](assets/cover.png)\n\n# Updated\n\nBody")
    }

    @Test
    func `note search and export filename use readable title`() {
        let note = Note(
            id: UUID(),
            filename: "note.md",
            createdAt: Date(),
            updatedAt: Date(),
            content: "# Hello, Swift GTK!",
        )

        #expect(note.matches(searchQuery: "swift gtk"))
        #expect(note.suggestedExportFilename == "hello-swift-gtk.md")
        #expect(note.stableID == note.id.uuidString.lowercased())
    }

    @Test
    func `renderer builds heading and paragraph blocks`() {
        let renderer = MarkdownRenderer()
        let blocks = renderer.blocks(for: "# Title\n\nParagraph", darkAppearance: false)
        #expect(blocks.count >= 2)
        #expect(blocks.first?.style == .heading(level: 1))
        #expect(blocks.first?.text == "Title")
    }

    @Test
    func `renderer builds task list markers`() {
        let renderer = MarkdownRenderer()
        let blocks = renderer.blocks(for: """
        - [x] Done
        - [ ] Todo
        """, darkAppearance: false)

        #expect(blocks.count == 2)
        #expect(blocks[0] == .listItem(text: .plain("Done"), depth: 0, marker: "[x]"))
        #expect(blocks[1] == .listItem(text: .plain("Todo"), depth: 0, marker: "[ ]"))
    }

    @Test
    func `renderer preserves task list markers when item contains inline markdown`() {
        let renderer = MarkdownRenderer()
        let blocks = renderer.blocks(for: """
        - [ ] Если было выделено **слово**, то после нажатия должно быть `код`
        """, darkAppearance: false)

        #expect(blocks.count == 1)
        guard case let .listItem(text, depth, marker) = blocks[0] else {
            Issue.record("Expected a task list item block")
            return
        }

        #expect(depth == 0)
        #expect(marker == "[ ]")
        #expect(text.plainText == "Если было выделено слово, то после нажатия должно быть код")
    }

    @Test
    func `renderer uses theme aware inline code background`() {
        let renderer = MarkdownRenderer()
        let lightBlocks = renderer.blocks(for: "Use `code` here", darkAppearance: false)
        let darkBlocks = renderer.blocks(for: "Use `code` here", darkAppearance: true)

        guard case let .paragraph(lightText) = lightBlocks.first,
              case let .paragraph(darkText) = darkBlocks.first
        else {
            Issue.record("Expected paragraph blocks")
            return
        }

        #expect(lightText.markup.contains("font_family=\"monospace\""))
        #expect(lightText.markup.contains("background=\"#f6f5f4\""))
        #expect(darkText.markup.contains("background=\"#3b3644\""))
        #expect(lightText.markup != darkText.markup)
    }

    @Test
    func `renderer builds standalone image block`() {
        let renderer = MarkdownRenderer()
        let blocks = renderer.blocks(
            for: "![Swift and Adwaita showcase artwork](markdown-demo-image.png)",
            darkAppearance: false,
        )

        #expect(blocks == [
            .image(
                alt: "Swift and Adwaita showcase artwork",
                source: "markdown-demo-image.png",
                title: nil,
            ),
        ])
    }

    @Test
    func `renderer builds standalone HTML image block`() {
        let renderer = MarkdownRenderer()
        let blocks = renderer.blocks(
            for: #"<img alt="Swift Adwaita" src="https://spaceinbox.me/images/swift-adwaita-2.webp">"#,
            darkAppearance: false,
        )

        #expect(blocks == [
            .image(
                alt: "Swift Adwaita",
                source: "https://spaceinbox.me/images/swift-adwaita-2.webp",
                title: nil,
            ),
        ])
    }

    @Test @MainActor
    func `renderer builds image group for linked badge images`() {
        let renderer = MarkdownRenderer()
        let blocks = renderer.blocks(for: """
        [![CI](https://github.com/makoni/swift-adwaita/actions/workflows/ci.yml/badge.svg)](https://github.com/makoni/swift-adwaita/actions/workflows/ci.yml)
        [![Swift 6.0+](https://img.shields.io/badge/Swift-6.0+-F05138.svg)](https://swift.org)
        """, darkAppearance: false)

        #expect(blocks == [
            .imageGroup(items: [
                .init(
                    alt: "CI",
                    source: "https://github.com/makoni/swift-adwaita/actions/workflows/ci.yml/badge.svg",
                    title: nil,
                    linkDestination: "https://github.com/makoni/swift-adwaita/actions/workflows/ci.yml",
                ),
                .init(
                    alt: "Swift 6.0+",
                    source: "https://img.shields.io/badge/Swift-6.0+-F05138.svg",
                    title: nil,
                    linkDestination: "https://swift.org",
                ),
            ]),
        ])
    }

    // MARK: - Image-only line segmentation (#16)
    //
    // CommonMark glues an image-only line that follows a paragraph (or
    // any other block) without an intervening blank line into the
    // previous paragraph as inline content. The renderer used to fall
    // back to a [Image: …] placeholder for those cases. We now segment
    // mixed-content paragraphs by line and promote image-only lines to
    // their own block, marking them as `.plain` so the preview renders
    // them in-flow without the heavier `.card` chrome.

    @Test
    func `renderer promotes an image right under a paragraph to a plain block image`() {
        let renderer = MarkdownRenderer()
        let blocks = renderer.blocks(for: """
        Some paragraph text
        ![alt text](image.png)
        """, darkAppearance: false)

        #expect(blocks.count == 2)
        guard case let .paragraph(text) = blocks.first else {
            Issue.record("Expected paragraph as the first block; got \(String(describing: blocks.first))")
            return
        }
        #expect(text.plainText.contains("Some paragraph text"))
        #expect(blocks.last == .image(
            alt: "alt text",
            source: "image.png",
            title: nil,
            style: .plain,
        ))
    }

    @Test
    func `renderer promotes an image right above a paragraph to a plain block image`() {
        let renderer = MarkdownRenderer()
        let blocks = renderer.blocks(for: """
        ![alt text](image.png)
        More paragraph text
        """, darkAppearance: false)

        #expect(blocks.count == 2)
        #expect(blocks.first == .image(
            alt: "alt text",
            source: "image.png",
            title: nil,
            style: .plain,
        ))
        guard case let .paragraph(text) = blocks.last else {
            Issue.record("Expected paragraph as the last block; got \(String(describing: blocks.last))")
            return
        }
        #expect(text.plainText.contains("More paragraph text"))
    }

    @Test
    func `renderer keeps card style for an image surrounded by blank lines`() {
        let renderer = MarkdownRenderer()
        let blocks = renderer.blocks(for: """
        Above

        ![alt](image.png)

        Below
        """, darkAppearance: false)

        // Three blocks in order: paragraph, card image, paragraph.
        #expect(blocks.count == 3)
        #expect(blocks[1] == .image(
            alt: "alt",
            source: "image.png",
            title: nil,
            style: .card,
        ))
    }

    @Test
    func `renderer keeps an inline image inside a sentence as part of the paragraph`() {
        // Image not on its own line — embedded mid-sentence with text on
        // both sides of the same line. Must NOT be split out; stays inline
        // in the paragraph (current placeholder fallback behaviour).
        let renderer = MarkdownRenderer()
        let blocks = renderer.blocks(
            for: "Click ![icon](icon.png) here to continue.",
            darkAppearance: false,
        )

        #expect(blocks.count == 1)
        guard case .paragraph = blocks.first else {
            Issue.record("Expected a single paragraph block; got \(String(describing: blocks.first))")
            return
        }
    }

    @Test
    func `renderer splits multiple image-only lines mixed with text into separate plain blocks`() {
        let renderer = MarkdownRenderer()
        let blocks = renderer.blocks(for: """
        Look at these:
        ![one](one.png)
        ![two](two.png)
        ![three](three.png)
        """, darkAppearance: false)

        // Paragraph then 3 plain image blocks — no grouping, since the
        // text introduces them and each line stands on its own.
        #expect(blocks.count == 4)
        guard case let .paragraph(intro) = blocks.first else {
            Issue.record("Expected intro paragraph; got \(String(describing: blocks.first))")
            return
        }
        #expect(intro.plainText.contains("Look at these"))
        #expect(blocks[1] == .image(alt: "one", source: "one.png", title: nil, style: .plain))
        #expect(blocks[2] == .image(alt: "two", source: "two.png", title: nil, style: .plain))
        #expect(blocks[3] == .image(alt: "three", source: "three.png", title: nil, style: .plain))
    }

    @Test
    func `renderer keeps a pure image-only paragraph as a card image group`() {
        // No surrounding text in the paragraph at all — author wants a
        // gallery-style standalone block. Card stays.
        let renderer = MarkdownRenderer()
        let blocks = renderer.blocks(for: """
        ![one](one.png)
        ![two](two.png)
        """, darkAppearance: false)

        #expect(blocks.count == 1)
        guard case let .imageGroup(items, style) = blocks.first else {
            Issue.record("Expected an image group; got \(String(describing: blocks.first))")
            return
        }
        #expect(style == .card)
        #expect(items.count == 2)
    }

    @Test
    func `renderer builds aligned table block`() {
        let renderer = MarkdownRenderer()
        let blocks = renderer.blocks(for: """
        | Feature | Example | Result |
        | :-- | :-- | :-: |
        | Emphasis | `**bold**` | Ready |
        | Checklist | `- [x] Ship it` | Ready |
        """, darkAppearance: false)

        guard case let .table(headers, rows, alignments) = blocks.first else {
            Issue.record("Expected a table block")
            return
        }

        #expect(headers.map(\.plainText) == ["Feature", "Example", "Result"])
        #expect(rows.count == 2)
        #expect(rows[0].map(\.plainText) == ["Emphasis", "**bold**", "Ready"])
        #expect(rows[1].map(\.plainText) == ["Checklist", "- [x] Ship it", "Ready"])
        #expect(alignments == [.leading, .leading, .center])
    }

    @Test
    func `html subset parser treats unsupported tags as literal text`() {
        let nodes = HTMLSubsetParser().parse("<pre><code>swiftynotes cli get <note-id></code></pre>")
        let blocks = HTMLPreviewDocumentBuilder(darkAppearance: false).blocks(from: nodes, listDepth: 0)

        #expect(blocks == [
            .codeBlock(code: "swiftynotes cli get <note-id>", language: nil),
        ])
    }

    @Test
    func `renderer builds blocks for CLI seed note`() {
        let renderer = MarkdownRenderer()
        let blocks = renderer.blocks(for: SwiftyNotesCLISeed.content, darkAppearance: false)

        #expect(!blocks.isEmpty)
        #expect(blocks.contains { block in
            if case let .heading(level, text) = block {
                return level == 1 && text.plainText == "Using Swifty Notes CLI"
            }
            return false
        })
        #expect(blocks.contains { block in
            if case let .codeBlock(code, language) = block {
                return language == "bash" && code.contains("swiftynotes cli list")
            }
            return false
        })
    }

    @Test
    func `preview render deferral waits for visible allocated preview pane`() {
        #expect(MainWindow.shouldDeferPreviewRender(
            isPreviewPresented: true,
            windowWidth: 1200,
            windowHeight: 800,
            hasParent: true,
            hasRoot: true,
            width: 0,
            height: 320,
        ))
        #expect(!MainWindow.shouldDeferPreviewRender(
            isPreviewPresented: true,
            windowWidth: 0,
            windowHeight: 0,
            hasParent: true,
            hasRoot: false,
            width: 540,
            height: 320,
        ))
    }

    @Test
    func `preview render deferral skips detached or hidden preview pane`() {
        #expect(!MainWindow.shouldDeferPreviewRender(
            isPreviewPresented: true,
            windowWidth: 1200,
            windowHeight: 800,
            hasParent: false,
            hasRoot: false,
            width: 0,
            height: 0,
        ))
        #expect(!MainWindow.shouldDeferPreviewRender(
            isPreviewPresented: false,
            windowWidth: 1200,
            windowHeight: 800,
            hasParent: true,
            hasRoot: false,
            width: 0,
            height: 0,
        ))
    }

    @Test @MainActor
    func `autosave coordinator runs latest task`() {
        let scheduler = TestMainActorScheduler()
        let autosave = AutosaveCoordinator(taskScheduler: scheduler.schedule(after:operation:))
        var values: [Int] = []

        autosave.scheduleSave(after: .milliseconds(10)) {
            values.append(1)
        }
        autosave.scheduleSave(after: .milliseconds(10)) {
            values.append(2)
        }

        scheduler.runPendingActions()

        #expect(values == [2])
    }
}
