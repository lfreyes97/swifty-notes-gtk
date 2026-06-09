import Foundation
@testable import SwiftyNotes
import Testing

/// Verifies emoji-shortcode substitution as it flows through the real
/// renderer (`:rocket:` → 🚀), including the contexts where it must NOT
/// fire (code spans / code blocks / link hrefs) and the off switch.
struct EmojiRenderingTests {
    private func blocks(_ markdown: String, emoji: Bool = true) -> [RenderedBlock] {
        MarkdownRenderer().blocks(for: markdown, darkAppearance: false, renderEmojiShortcodes: emoji)
    }

    @Test("Emoji renders in a paragraph")
    func emojiRendersInParagraph() {
        let result = blocks("Shipped it :rocket: today")
        #expect(result.first?.plainText == "Shipped it 🚀 today")
    }

    @Test("Emoji renders in headings, blockquotes, and list items")
    func emojiRendersInHeadingsQuotesAndLists() {
        #expect(blocks("# Done :white_check_mark:").first?.plainText == "Done ✅")
        #expect(blocks("> quote :tada:").first?.plainText.contains("🎉") == true)

        let list = blocks("- first :rocket:\n- second :tada:")
        let listText = list.map(\.plainText).joined(separator: "\n")
        #expect(listText.contains("🚀"))
        #expect(listText.contains("🎉"))
    }

    @Test("Emoji renders inside table cells")
    func emojiRendersInTableCells() {
        let md = """
        | a | b |
        |---|---|
        | :rocket: | plain |
        """
        let table = blocks(md).first
        #expect(table?.plainText.contains("🚀") == true)
    }

    @Test("Emoji renders in a bare top-level text run")
    func emojiRendersInBareTextRun() {
        // Some markdown lands as a loose text node rather than a <p>; that
        // path builds RenderedText via `.plain(_:)`, not `inlineText`.
        let result = blocks("just text :rocket:")
        #expect(result.contains { $0.plainText.contains("🚀") })
    }

    @Test("Shortcodes inside an inline code span are left literal")
    func inlineCodeSpanStaysLiteral() {
        // `:rocket:` in backticks must stay as-is — the descent into the
        // <code> element disables substitution.
        let result = blocks("use `:rocket:` literally")
        #expect(result.first?.plainText == "use :rocket: literally")
        #expect(result.first?.plainText.contains("🚀") == false)
    }

    @Test("Shortcodes inside a fenced code block are left literal")
    func fencedCodeBlockStaysLiteral() {
        let md = """
        ```
        launch = ":rocket:"
        ```
        """
        let block = blocks(md).first
        #expect(block?.plainText.contains(":rocket:") == true)
        #expect(block?.plainText.contains("🚀") == false)
    }

    @Test("A link label renders emoji but the href is untouched")
    func linkLabelRendersButHrefUntouched() {
        // The label text goes through `.text` (substituted); the href is read
        // straight from the attribute and must keep its literal colons.
        let result = blocks("[:rocket:](https://example.com/:rocket:/path)")
        guard case let .paragraph(text)? = result.first else {
            Issue.record("expected a paragraph with a link")
            return
        }
        #expect(text.plainText.contains("🚀"))
        // The href in the Pango markup keeps the literal ':rocket:' path.
        #expect(text.markup.contains("https://example.com/:rocket:/path"))
    }

    @Test("Substitution is skipped when the setting is off")
    func substitutionSkippedWhenSettingOff() {
        let result = blocks("Shipped :rocket:", emoji: false)
        #expect(result.first?.plainText == "Shipped :rocket:")
        #expect(result.first?.plainText.contains("🚀") == false)
    }
}
