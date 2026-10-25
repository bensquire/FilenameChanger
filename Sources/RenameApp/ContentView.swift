import AppKit
import QuickLook
import RenameKit
import SwiftUI

public struct ContentView: View {
    @Bindable var model: AppModel
    @Environment(\.undoManager) private var undoManager

    @State private var presetName = ""
    @State private var previewItem: URL?
    @State private var renamingID: PlannedRename.ID?
    @State private var renameText = ""

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        // Compute the plan once per render and hand it to the subviews, rather
        // than recomputing it (disk + EXIF work) separately in each.
        let plan = model.plan
        let toRename = RenameEngine.actionableRenames(plan).count
        VStack(spacing: 0) {
            fileTable(plan)
            Divider()
            parameterSection
        }
        .frame(minWidth: 760, minHeight: 520)
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar(plan, toRename: toRename) }
        .toolbar { toolbarContent }
        .navigationTitle("FilenameChanger")
        .focusedSceneValue(\.renameTarget, toRename > 0 ? RenameTarget(undoManager: undoManager) : nil)
        .sheet(isPresented: $model.isSavingPreset) {
            TextEntrySheet(
                title: "Save Current Rename", prompt: "Preset name", text: $presetName,
                confirmLabel: "Save"
            ) {
                model.saveCurrentAsPreset(named: presetName)
            }
            .onAppear { presetName = "" }
        }
        .sheet(isPresented: $model.isShowingHistory) { HistoryView(model: model) }
        .sheet(isPresented: renamingSheetShown) {
            TextEntrySheet(
                title: "Rename File", prompt: "Name", text: $renameText, confirmLabel: "Rename"
            ) {
                if let id = renamingID {
                    model.renameSingle(id, to: renameText, undoManager: undoManager)
                }
            }
        }
        .alert("Couldn’t rename some files", isPresented: failureAlertShown) {
            Button("OK", role: .cancel) { model.renameFailures = [] }
        } message: {
            Text(
                "These names are already taken, or the files couldn’t be moved:\n"
                    + model.renameFailures.joined(separator: "\n"))
        }
    }

    // MARK: - Table

    private func fileTable(_ plan: [PlannedRename]) -> some View {
        Table(of: PlannedRename.self, selection: $model.selection) {
            TableColumn("") { row in
                Toggle(
                    "",
                    isOn: Binding(
                        get: { row.isEnabled },
                        set: { model.setEnabled($0, for: row.id) })
                )
                .labelsHidden()
                .accessibilityLabel("Include \(row.originalName)")
            }
            .width(26)
            TableColumn("Original Name") { row in
                Label {
                    Text(model.options.displayName(for: row.originalName))
                        .foregroundStyle(row.isEnabled ? .primary : .tertiary)
                } icon: {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: row.url.path(percentEncoded: false)))
                        .resizable().frame(width: 16, height: 16)
                }
            }
            TableColumn("New Name") { row in
                newNameCell(row)
            }
        } rows: {
            // Drag a row to reorder — this is the custom order a Sequence
            // rename numbers against.
            ForEach(plan) { row in
                TableRow(row)
                    .draggable(row.id.uuidString)
            }
            .dropDestination(for: String.self) { index, droppedIDs in
                // The drop offset indexes the displayed rows, which match the
                // file list only when the list isn't being sorted for Sequence.
                // Ignore drops while a non-custom sort is active so the custom
                // order isn't scrambled behind the sorted view.
                guard model.kind != .sequence || model.sequence.sort == .custom else { return }
                model.moveRows(ids: droppedIDs, toOffset: index)
            }
        }
        .tableStyle(.inset)
        // Spacebar Quick Look, as in Finder. Only while the file list has
        // focus, so a space typed into a parameter field stays a space.
        // /documentation/swiftui/view/onkeypress(_:action:)
        .onKeyPress(.space) {
            togglePreview(plan)
            return .handled
        }
        .contextMenu(forSelectionType: PlannedRename.ID.self) { ids in
            rowMenu(ids)
        } primaryAction: { ids in
            beginRename(ids)  // double-click (or Return) edits the single row
        }
        .onDeleteCommand { model.removeSelected() }
        .quickLookPreview($previewItem, in: plan.map(\.url))
        .dropDestination(for: URL.self) { urls, _ in
            model.add(urls: FileAdder.expandForDrop(urls))
            return true
        }
        .overlay {
            if model.items.isEmpty {
                ContentUnavailableView(
                    "No Files", systemImage: "doc.badge.plus",
                    description: Text("Add files, or drag them here, to start renaming."))
            }
        }
    }

    @ViewBuilder private func newNameCell(_ row: PlannedRename) -> some View {
        let original = model.options.displayName(for: row.originalName)
        let proposed = model.options.displayName(for: row.proposedName)
        let reading = model.readingStatus(for: row.id)
        if reading == .pending {
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text("Reading…").foregroundStyle(.secondary)
            }
        } else if case let .failed(reason) = reading {
            warningCell(proposed, reason: reason)
        } else if let issue = row.issue {
            warningCell(proposed, reason: issueText(issue))
        } else if row.willRename {
            NameDiffText(original: original, proposed: proposed)
        } else {
            Text(proposed)
                .foregroundStyle(.tertiary)
                .help("No change for this file.")
        }
    }

    /// A grey name with an orange warning, and why on hover: a row that
    /// can't be renamed.
    private func warningCell(_ proposed: String, reason: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
            Text(proposed).foregroundStyle(.secondary)
        }
        .help(reason)
        .accessibilityLabel("\(proposed), \(reason)")
    }

    // MARK: - Row actions

    @ViewBuilder private func rowMenu(_ ids: Set<PlannedRename.ID>) -> some View {
        Button("Rename…") { beginRename(ids) }
            .disabled(ids.count != 1)
        Button("Reveal in Finder") { reveal(ids) }
            .disabled(ids.isEmpty)
        Divider()
        Button("Remove") { model.remove(ids: ids) }
            .disabled(ids.isEmpty)
    }

    private func beginRename(_ ids: Set<PlannedRename.ID>) {
        guard let id = ids.first, ids.count == 1,
            let item = model.items.first(where: { $0.id == id })
        else { return }
        renameText = item.originalName
        renamingID = id
    }

    private func reveal(_ ids: Set<PlannedRename.ID>) {
        let urls = model.items.filter { ids.contains($0.id) }.map(\.url)
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    private var renamingSheetShown: Binding<Bool> {
        Binding(get: { renamingID != nil }, set: { if !$0 { renamingID = nil } })
    }

    private var failureAlertShown: Binding<Bool> {
        Binding(get: { !model.renameFailures.isEmpty }, set: { if !$0 { model.renameFailures = [] } })
    }

    private func issueText(_ issue: RenameIssue) -> String {
        switch issue {
        case .collision: return "A file with this name already exists."
        case .duplicateResult: return "Another row would get this same name."
        case .invalidName: return "This name is empty or contains a “/”."
        }
    }

    private func togglePreview(_ plan: [PlannedRename]) {
        if previewItem != nil {
            previewItem = nil
            return
        }
        // The first selected row in table order (selection is an unordered set),
        // or the first row when nothing is selected.
        let row = plan.first(where: { model.selection.contains($0.id) }) ?? plan.first
        previewItem = row?.url
    }

    // MARK: - Parameters

    private var parameterSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("Rename")
                        .foregroundStyle(.secondary)
                        .frame(width: FunctionParametersView.labelWidth, alignment: .trailing)
                    // Labelled for VoiceOver; the visible "Rename" text sits beside it.
                    Picker("Rename function", selection: $model.kind) {
                        ForEach(FunctionKind.allCases) { kind in
                            // Set apart: the one function that reads the files.
                            if kind == .smartName { Divider() }
                            Text(kind.title).tag(kind)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 260, alignment: .leading)
                    Spacer()
                    presetMenu
                    Button {
                        model.isShowingHistory = true
                    } label: {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }
                    .hoverHighlight()
                }
                Divider()
                FunctionParametersView(model: model)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
    }

    // MARK: - Bottom bar

    private func bottomBar(_ plan: [PlannedRename], toRename: Int) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 18) {
                Toggle("Hide extensions", isOn: $model.options.hideExtension)
                Toggle("Ignore case", isOn: $model.options.ignoreCase)
                Toggle("Force unique", isOn: $model.options.forceUnique)
                Spacer()
                statusText(plan, toRename: toRename)
                Button {
                    model.performRename(undoManager: undoManager)
                } label: {
                    Label("Rename", systemImage: "character.cursor.ibeam")
                        .frame(minWidth: 72)
                }
                // ⌘↩ lives on File ▸ Rename, so the menu bar shows it.
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(toRename == 0)
                .hoverHighlight()
            }
            .toggleStyle(.checkbox)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }

    private func statusText(_ plan: [PlannedRename], toRename: Int) -> some View {
        let issues = plan.count { $0.issue != nil }
        return HStack(spacing: 10) {
            Text("\(model.items.count) files · \(toRename) to rename")
                .foregroundStyle(.secondary)
            if issues > 0 {
                Label("\(issues)", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
        .font(.callout)
    }

    // MARK: - Preset menu / sheets

    private var presetMenu: some View {
        Menu {
            Button("Save Current Rename…") { model.isSavingPreset = true }
            if !model.presets.isEmpty {
                Divider()
                PresetMenuItems(model: model)
            }
        } label: {
            Label("Presets", systemImage: "square.stack.3d.up")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            Menu {
                Button("Add Files…") { add(.items) }
                Button("Add Folder Contents…") { add(.folderContents) }
                Button("Add Folder Contents (Recursive)…") { add(.recursive) }
            } label: {
                Label("Add", systemImage: "plus")
            } primaryAction: {
                add(.items)
            }
            .help("Add files or folders")

            Button {
                model.removeSelected()
            } label: {
                Label("Remove", systemImage: "minus")
            }
            .disabled(model.selection.isEmpty)
            .help("Remove the selected files")

            Button {
                model.clear()
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .disabled(model.items.isEmpty)
            .help("Remove all files")
        }
    }

    // MARK: - Helpers

    private func add(_ mode: FileAdder.Mode) {
        FileAdder.present(mode: mode) { urls in model.add(urls: urls) }
    }
}

/// A small modal prompt: a title, one text field, and Cancel/confirm buttons.
/// Shared by the Save-preset and single-file-rename sheets. Dismisses itself
/// through the environment, which drives the presenting binding closed.
private struct TextEntrySheet: View {
    let title: String
    let prompt: String
    @Binding var text: String
    let confirmLabel: String
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.headline)
            TextField(prompt, text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300, alignment: .leading)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(confirmLabel) {
                    onConfirm()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
    }
}
