import Adwaita
import Foundation

// The find/replace implementation lives in ``FindReplaceCoordinator``
// (shared with ``MainWindow``); this file only forwards the
// window-level entry points used by the launcher's app-level actions
// and the preview pipeline.
@MainActor
extension ExternalDocumentWindow {
    func openFindBar(mode: FindReplaceBar.Mode) {
        findReplace.openFindBar(mode: mode)
    }

    /// Called after every preview re-render so the preview's search
    /// controller (if active) can refresh its match cache.
    func refreshPreviewSearchAfterRerender() {
        findReplace.onPreviewRerendered()
    }

    var editorSearchController: EditorSearchController? {
        findReplace.editorSearchController
    }

    var previewSearchController: PreviewSearchController? {
        findReplace.previewSearchController
    }
}
