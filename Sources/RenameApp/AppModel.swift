import Foundation
import Observation
import RenameKit

/// UI-facing mode for Remove Characters.
public enum RemoveModeKind: String, CaseIterable, Sendable {
    case range
    case fromEnd
}

/// UI-facing mode for Insert Characters.
public enum InsertModeKind: String, CaseIterable, Sendable {
    case atIndex
    case fromEnd
}

/// UI-facing mode for the Date source.
public enum DateSourceKind: String, CaseIterable, Sendable {
    case custom
    case fileCreated
    case exif
}

/// The whole of the app's state: the files in the table, the chosen function
/// and its parameters, the options, and the saved presets and history. Views
/// read and bind to it; all file-system work funnels through `performRename`.
@MainActor
@Observable
public final class AppModel {
    // The files queued for renaming, in table order.
    public var items: [FileItem] = []
    public var selection: Set<FileItem.ID> = []
    /// What went wrong in the last rename: target names that couldn't be
    /// written, and any file a rollback couldn't put back. Non-empty drives
    /// the "couldn't rename" alert.
    public var renameFailures: [String] = []
    // The window's sheets, opened from its buttons and the File menu alike.
    public var isSavingPreset = false
    public var isShowingHistory = false

    // Which function, and its editable parameters.
    public var kind: FunctionKind = .prepend
    // Hide Extensions defaults on so every function operates on the name and
    // leaves the extension intact; turn it off to deliberately edit extensions
    // (e.g. Replace/Regex, or replacing the whole name including its extension).
    public var options = RenameOptions(hideExtension: true)

    // Prepend / Append.
    public var prependText = ""
    public var appendText = ""

    // Replace family + wildcard + regex (find/replace reused across them).
    public var findText = ""
    public var replaceText = ""

    // Remove Characters.
    public var removeMode: RemoveModeKind = .range
    public var removeLocation = 0
    public var removeLength = 1
    public var removeFromEnd = 1

    // Insert Characters.
    public var insertText = ""
    public var insertMode: InsertModeKind = .atIndex
    public var insertIndex = 0
    public var padEnabled = false
    public var padLength = 1

    // Change Case.
    public var textCase: TextCase = .title

    // Clean Up.
    public var cleanUp = CleanUpConfig()

    // Sequence.
    public var sequence = SequenceConfig()

    // Date.
    public var dateSource: DateSourceKind = .fileCreated
    public var customDate = Date()
    public var usePresetDate = true
    public var datePreset: DatePreset = .isoDash
    public var customDatePattern = "yyyy-MM-dd"
    public var datePlacement: Placement = .prepend

    // Presets and history, persisted as JSON.
    public var presets: [Preset] = []
    public var history: [HistoryEntry] = []

    private let provider: FileMetadataProvider
    private let store: PersistenceStore
    /// The one call that changes the user's files. `FileManager.moveItem`
    /// never overwrites; injected so tests can make a move fail on demand.
    private let moveItem: (URL, URL) throws -> Void

    public init(
        provider: FileMetadataProvider = SystemFileMetadataProvider(),
        store: PersistenceStore = PersistenceStore(),
        moveItem: @escaping (URL, URL) throws -> Void = {
            try FileManager.default.moveItem(at: $0, to: $1)
        }
    ) {
        self.provider = provider
        self.store = store
        self.moveItem = moveItem
        self.presets = store.loadPresets()
        self.history = store.loadHistory()
    }

    /// The `RenameFunction` assembled from the current kind and parameters.
    public var function: RenameFunction {
        switch kind {
        case .prepend: return .prepend(text: prependText)
        case .append: return .append(text: appendText)
        case .replaceFirst: return .replaceFirst(find: findText, with: replaceText)
        case .replaceLast: return .replaceLast(find: findText, with: replaceText)
        case .replaceAll: return .replaceAll(find: findText, with: replaceText)
        case .wildcard: return .wildcard(find: findText, with: replaceText)
        case .regex: return .regex(pattern: findText, template: replaceText)
        case .removeCharacters:
            switch removeMode {
            case .range: return .removeCharacters(.range(location: removeLocation, length: removeLength))
            case .fromEnd: return .removeCharacters(.fromEnd(count: removeFromEnd))
            }
        case .insertCharacters:
            let mode: InsertMode = insertMode == .atIndex ? .atIndex(insertIndex) : .fromEnd
            return .insertCharacters(text: insertText, mode: mode, padToLength: padEnabled ? padLength : nil)
        case .changeCase: return .changeCase(textCase)
        case .cleanUp: return .cleanUp(cleanUp)
        case .sequence: return .sequence(sequence)
        case .date: return .date(dateConfig)
        }
    }

    private var dateConfig: DateConfig {
        let source: DateSource
        switch dateSource {
        case .custom: source = .custom(customDate)
        case .fileCreated: source = .fileCreated
        case .exif: source = .exif
        }
        let format: DateFormatChoice =
            usePresetDate ? .preset(datePreset) : .custom(customDatePattern)
        return DateConfig(source: source, format: format, placement: datePlacement)
    }

    /// The live plan, recomputed from the current files, function and options.
    public var plan: [PlannedRename] {
        RenameEngine.plan(items: items, function: function, options: options, provider: provider)
    }

    // MARK: - File list

    public func add(urls: [URL]) {
        // Keyed by file identity, not the exact URL, and checked within the
        // incoming batch too: one drop can name a file twice (a folder plus a
        // file inside it), or spell it two ways ("/var/…" vs "/private/var/…").
        var seen = Set(items.map { Self.identityKey($0.url) })
        for url in urls where seen.insert(Self.identityKey(url)).inserted {
            items.append(FileItem(url: url))
        }
    }

    /// The folder resolved through symlinks plus the file's own name, so two
    /// URLs naming the same file share a key. The file itself isn't resolved:
    /// a symlink stays a separate item from its target.
    private static func identityKey(_ url: URL) -> String {
        let url = url.standardizedFileURL  // fold "x/.." first
        return url.deletingLastPathComponent().resolvingSymlinksInPath()
            .appending(component: url.lastPathComponent).path(percentEncoded: false)
    }

    public func removeSelected() {
        remove(ids: selection)
    }

    public func remove(ids: Set<FileItem.ID>) {
        items.removeAll { ids.contains($0.id) }
        selection.subtract(ids)
    }

    public func clear() {
        items.removeAll()
        selection.removeAll()
    }

    public func setEnabled(_ enabled: Bool, for id: FileItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isEnabled = enabled
    }

    /// Reorder the table: move the dragged rows to `offset` (the drop position
    /// among the current rows). Used by the table's drag-to-reorder.
    public func moveRows(ids droppedIDStrings: [String], toOffset offset: Int) {
        let draggedIDs = Set(droppedIDStrings.compactMap(UUID.init(uuidString:)))
        let source = IndexSet(items.indices.filter { draggedIDs.contains(items[$0].id) })
        guard !source.isEmpty else { return }
        items.move(fromOffsets: source, toOffset: offset)
    }

    // MARK: - Rename

    /// Apply the plan: move each actionable file, record history, and register
    /// an undo that moves them back. The batch is ordered so chained renames
    /// (shifts, swaps, rotations) run safely, and it is all-or-nothing — any
    /// failure rolls the whole batch back — so a file is never stranded.
    public func performRename(undoManager: UndoManager?) {
        renameFailures = []  // clear any earlier run's failures before starting
        let actions = RenameEngine.actionableRenames(plan)
        guard !actions.isEmpty else { return }

        let moves = actions.map { MoveOp(from: $0.url, to: $0.url.renamed(to: $0.proposedName)) }
        let ordered = RenameSequencer.ordered(moves)
        let rows = actions.map { HistoryEntry.Row(original: $0.originalName, renamed: $0.proposedName) }

        let failures = applyMoves(ordered, undoManager: undoManager, actionName: "Rename")
        if failures.isEmpty {
            recordHistory(rows)
        } else {
            renameFailures = failures
        }
    }

    /// Rename a single file now (double-click / context menu), outside the
    /// batch plan. Returns false — and populates `renameFailures` — when the
    /// name is empty, contains a "/", is taken, or the move fails.
    @discardableResult
    public func renameSingle(_ id: FileItem.ID, to newName: String, undoManager: UndoManager?)
        -> Bool
    {
        guard let item = items.first(where: { $0.id == id }) else { return false }
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        // Validate and check for collisions with the same engine rules — and
        // the same injected provider — the batch plan uses, so collision
        // semantics live in one place.
        let planned = RenameEngine.planOverride(name: trimmed, for: item, provider: provider)
        guard planned.willRename, planned.issue == nil else {
            // A real problem (taken name, or "/"/"."/".." etc.) is surfaced; an
            // unchanged name is just a silent no-op.
            if planned.issue != nil { renameFailures = [trimmed] }
            return false
        }
        let failures = applyMoves(
            [MoveOp(from: item.url, to: item.url.renamed(to: trimmed))],
            undoManager: undoManager, actionName: "Rename")
        guard failures.isEmpty else {
            renameFailures = failures
            return false
        }
        recordHistory([.init(original: item.originalName, renamed: trimmed)])
        return true
    }

    /// Execute moves in order, updating the table and registering the inverse
    /// for undo. All-or-nothing: on the first failure every completed move is
    /// rolled back. Returns what went wrong — empty when the whole batch
    /// succeeded. A rollback move can itself fail (a file locked or deleted
    /// outside the app): that file stays where it is, possibly under a
    /// temporary name from a half-finished cycle, the table keeps pointing at
    /// its real location, and the returned message says where it was left.
    private func applyMoves(_ moves: [MoveOp], undoManager: UndoManager?, actionName: String)
        -> [String]
    {
        var done: [MoveOp] = []
        for move in moves {
            do {
                try moveItem(move.from, move.to)
                updateItemURL(from: move.from, to: move.to)
                done.append(move)
            } catch {
                var failures = [move.to.lastPathComponent]
                // Undo the completed moves, newest first, back to the start.
                for completed in done.reversed() {
                    do {
                        try moveItem(completed.to, completed.from)
                        updateItemURL(from: completed.to, to: completed.from)
                    } catch {
                        failures.append(
                            "\(completed.from.lastPathComponent) (left as \(completed.to.lastPathComponent))")
                    }
                }
                return failures
            }
        }
        guard !done.isEmpty else { return [] }
        let inverse = done.reversed().map { MoveOp(from: $0.to, to: $0.from) }
        undoManager?.registerUndo(withTarget: self) { model in
            // Surface any failure of the undo itself (e.g. a file moved or
            // deleted outside the app since) rather than failing silently.
            let failures = model.applyMoves(inverse, undoManager: undoManager, actionName: actionName)
            if !failures.isEmpty { model.renameFailures = failures }
        }
        undoManager?.setActionName(actionName)
        return []
    }

    private func updateItemURL(from: URL, to: URL) {
        guard let index = items.firstIndex(where: { $0.url == from }) else { return }
        items[index].url = to
    }

    // MARK: - Presets

    public func saveCurrentAsPreset(named name: String) {
        presets.removeAll { $0.name == name }
        presets.append(Preset(name: name, kind: kind, function: function, options: options))
        store.savePresets(presets)
    }

    public func apply(_ preset: Preset) {
        kind = preset.kind
        options = preset.options
        loadParameters(from: preset.function)
    }

    public func deletePreset(named name: String) {
        presets.removeAll { $0.name == name }
        store.savePresets(presets)
    }

    // MARK: - History

    private func recordHistory(_ rows: [HistoryEntry.Row]) {
        history.insert(HistoryEntry(date: Date(), rows: rows), at: 0)
        if history.count > 50 { history = Array(history.prefix(50)) }
        store.saveHistory(history)
    }

    public func clearHistory() {
        history.removeAll()
        store.saveHistory(history)
    }

    /// Unpack a function value back into the editable parameter fields.
    private func loadParameters(from function: RenameFunction) {
        switch function {
        case let .prepend(text): prependText = text
        case let .append(text): appendText = text
        case let .replaceFirst(find, with), let .replaceLast(find, with),
            let .replaceAll(find, with), let .wildcard(find, with):
            findText = find
            replaceText = with
        case let .regex(pattern, template):
            findText = pattern
            replaceText = template
        case let .removeCharacters(mode):
            switch mode {
            case let .range(location, length):
                removeMode = .range
                removeLocation = location
                removeLength = length
            case let .fromEnd(count):
                removeMode = .fromEnd
                removeFromEnd = count
            }
        case let .insertCharacters(text, mode, pad):
            insertText = text
            switch mode {
            case let .atIndex(index):
                insertMode = .atIndex
                insertIndex = index
            case .fromEnd:
                insertMode = .fromEnd
            }
            padEnabled = pad != nil
            if let pad { padLength = pad }
        case let .changeCase(value): textCase = value
        case let .cleanUp(config): cleanUp = config
        case let .sequence(config): sequence = config
        case let .date(config): loadDate(config)
        }
    }

    private func loadDate(_ config: DateConfig) {
        switch config.source {
        case let .custom(date):
            dateSource = .custom
            customDate = date
        case .fileCreated: dateSource = .fileCreated
        case .exif: dateSource = .exif
        }
        switch config.format {
        case let .preset(preset):
            usePresetDate = true
            datePreset = preset
        case let .custom(pattern):
            usePresetDate = false
            customDatePattern = pattern
        }
        datePlacement = config.placement
    }
}
