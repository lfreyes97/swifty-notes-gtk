import Adwaita
import Foundation

@MainActor
extension MainWindow {
    func configureViewModeToggleContent() {
        setToggleContent(
            editorModeToggle,
            label: "Editor",
            iconName: "document-edit-symbolic"
        )
        setToggleContent(
            splitModeToggle,
            label: "Split",
            iconName: "view-dual-symbolic"
        )
        setToggleContent(
            previewModeToggle,
            label: "Preview",
            iconName: "text-x-generic-symbolic"
        )
    }

    func configureEditorFormattingToolbar() {
        guard editorFormattingButtons.isEmpty else { return }

        editorFormattingBar.addCSSClass(.toolbar)
        editorFormattingBar.marginStart = 8
        editorFormattingBar.marginEnd = 8
        editorFormattingBar.marginTop = 8
        editorFormattingBar.marginBottom = 8
        editorFormattingBar.hexpand = true

        editorInlineFormattingGroup.addCSSClass("linked")
        editorBlockFormattingGroup.addCSSClass("linked")

        let inlineActions: [MarkdownFormattingAction] = [.heading, .bold, .italic, .code, .link]
        let blockActions: [MarkdownFormattingAction] = [.quote, .bulletList, .numberedList, .taskList]

        for action in inlineActions {
            let button = makeEditorFormattingButton(for: action)
            editorInlineFormattingGroup.append(button)
            editorFormattingButtons[action] = button
        }

        for action in blockActions {
            let button = makeEditorFormattingButton(for: action)
            editorBlockFormattingGroup.append(button)
            editorFormattingButtons[action] = button
        }

        editorFormattingBar.append(editorInlineFormattingGroup)
        editorFormattingBar.append(Separator(orientation: .vertical))
        editorFormattingBar.append(editorBlockFormattingGroup)
    }

    func applyEditorFormatting(_ action: MarkdownFormattingAction) {
        guard state.selectedNote != nil else { return }
        editor.applyFormatting(action)
    }

    private func makeEditorFormattingButton(for action: MarkdownFormattingAction) -> Button {
        let button = Button()
        button.tooltipText = action.tooltip
        button.setAccessibleLabel(action.accessibilityLabel)
        button.child = makeToolbarButtonContent(
            primaryText: action.shortLabel ?? action.accessibilityLabel,
            iconName: action.iconName,
            prefersCompactLabel: action.iconName != nil && action.shortLabel == nil
        )
        return button
    }

    private func setToggleContent(_ toggle: ToggleButton, label: String, iconName: String) {
        toggle.child = makeToolbarButtonContent(
            primaryText: label,
            iconName: iconName,
            prefersCompactLabel: false
        )
    }

    private func makeToolbarButtonContent(
        primaryText: String,
        iconName: String?,
        prefersCompactLabel: Bool
    ) -> Widget {
        let box = Box(orientation: .horizontal, spacing: 6)
        box.marginStart = prefersCompactLabel ? 2 : 4
        box.marginEnd = prefersCompactLabel ? 2 : 4

        if let iconName {
            let image = Image(iconName: iconName)
            image.pixelSize = 16
            box.append(image)
        }

        let label = Label(primaryText)
        label.xalign = 0
        if prefersCompactLabel {
            label.addCSSClass(.caption)
        }
        box.append(label)
        return box
    }
}
