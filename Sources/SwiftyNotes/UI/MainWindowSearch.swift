import Adwaita
import Foundation

@MainActor
extension MainWindow {
    /// Lazily builds the editor search controller. Called by
    /// `wireSignals` once the editor buffer + bar exist.
    func wireFindReplaceBar() {
        guard editorSearchController == nil else { return }
        let controller = EditorSearchController(
            bar: findReplaceBar,
            view: editor.view,
            buffer: editor.buffer,
        )
        controller.onReplaceAllCompleted = { [weak self] count in
            let message: String
            switch count {
            case 0:
                message = "No matches to replace."
            case 1:
                message = "Replaced 1 occurrence."
            default:
                message = "Replaced \(count) occurrences."
            }
            self?.toastOverlay.addToast(Toast(title: message))
        }
        editorSearchController = controller

        // Wire AdwSearchBar's built-in key capture so Esc closes the
        // bar from anywhere in the window — without this, Esc only
        // works when focus is already on the bar's own widgets.
        findReplaceBar.root.setKeyCaptureWidget(window)

        // When the bar closes, return focus to the editor cursor —
        // GNOME convention. (Esc inside the bar already does this;
        // this covers programmatic close + the close-button path.)
        let existingOnClose = findReplaceBar.onClose
        findReplaceBar.onClose = { [weak self] in
            existingOnClose?()
            self?.editor.focus()
        }
    }

    /// Open the find / replace bar in the requested mode. Pre-fills
    /// the query from the editor's current selection — same
    /// affordance every GNOME app offers (selection becomes "what I
    /// want to find").
    func openFindBar(mode: FindReplaceBar.Mode) {
        wireFindReplaceBar()
        prefillBarFromSelection()
        findReplaceBar.setVisible(true, mode: mode)
        // Pre-fill is silent (programmatic setter doesn't trigger
        // onQueryChanged) — so explicitly notify so the controller
        // computes match count + auto-steps on first display.
        findReplaceBar.notifyQueryChanged()
    }

    private func prefillBarFromSelection() {
        let selection = editor.buffer.selectedRange
        // Only adopt the selection if it's a single-line range —
        // multi-line selections rarely encode a meaningful query
        // and they'd populate the find entry with a line break.
        guard !selection.isEmpty else { return }
        let text = editor.buffer.text
        let startOffset = selection.lowerBound
        let endOffset = selection.upperBound
        guard startOffset <= endOffset, endOffset <= text.count else { return }
        let startIndex = text.index(text.startIndex, offsetBy: startOffset)
        let endIndex = text.index(text.startIndex, offsetBy: endOffset)
        let selected = String(text[startIndex..<endIndex])
        if selected.contains("\n") { return }
        findReplaceBar.query = selected
    }
}
