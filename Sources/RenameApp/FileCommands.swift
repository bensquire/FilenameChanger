import SwiftUI

/// What File ▸ Rename needs from the window, published by `ContentView`: its
/// undo manager, which the batch registers with. A value, not a closure, so
/// the menu updates only when it changes.
/// /documentation/swiftui/view/focusedscenevalue(_:_:)
struct RenameTarget: Equatable {
    let undoManager: UndoManager?
}

extension FocusedValues {
    /// Nil while there is nothing to rename.
    @Entry var renameTarget: RenameTarget?
}

/// The File menu: every toolbar and bottom-bar action, so each can be found
/// in the menu bar and the common ones carry their shortcut.
public struct FileCommands: Commands {
    let model: AppModel
    @FocusedValue(\.renameTarget) private var renameTarget

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Add Files…") { add(.items) }
                .keyboardShortcut("o", modifiers: .command)
            Button("Add Folder Contents…") { add(.folderContents) }
            Button("Add Folder Contents (Recursive)…") { add(.recursive) }
            Button("Remove All Files") { model.clear() }
                .disabled(model.items.isEmpty)
            Divider()
            Button("Rename") {
                if let renameTarget { model.performRename(undoManager: renameTarget.undoManager) }
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(renameTarget == nil)
            Divider()
            Button("Save Current Rename…") { model.isSavingPreset = true }
            // `.disabled` on a submenu here is ignored, so an empty one
            // says so rather than offering an empty Delete.
            Menu("Presets") {
                if model.presets.isEmpty {
                    Button("No Saved Presets") {}
                        .disabled(true)
                } else {
                    PresetMenuItems(model: model)
                }
            }
            Button("History…") { model.isShowingHistory = true }
        }
    }

    private func add(_ mode: FileAdder.Mode) {
        FileAdder.present(mode: mode) { model.add(urls: $0) }
    }
}

/// Apply a preset, or delete one: shared by the window's Presets menu and the
/// menu bar's, so the two can't drift apart.
struct PresetMenuItems: View {
    let model: AppModel

    var body: some View {
        ForEach(model.presets) { preset in
            Button(preset.name) { model.apply(preset) }
        }
        Divider()
        Menu("Delete") {
            ForEach(model.presets) { preset in
                Button(preset.name) { model.deletePreset(named: preset.name) }
            }
        }
    }
}
