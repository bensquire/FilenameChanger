import Foundation
import Observation
import RenameIntelligence
import RenameKit

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

    /// The rename as a chain of steps, run in order; one step is a plain
    /// rename. Never empty.
    public var steps = [FunctionSettings()] {
        didSet {
            selectedStepIndex = min(selectedStepIndex, steps.count - 1)
            // Only when a step that reads documents arrives: not on every
            // keystroke in a step's fields. New files are read as they're added.
            if !oldValue.contains(where: { $0.function.readsDocument }) { analyzeIfNeeded() }
        }
    }
    /// The step the panel is editing; always one of `steps`.
    public var selectedStepIndex = 0
    // Hide Extensions defaults on so every function operates on the name and
    // leaves the extension intact; turn it off to deliberately edit extensions
    // (e.g. Replace/Regex, or replacing the whole name including its extension).
    public var options = RenameOptions(hideExtension: true)
    /// What Smart Name read in each file.
    public let analysis: DocumentAnalysis

    // Presets and history, persisted as JSON.
    public var presets: [Preset] = []
    public var history: [HistoryEntry] = []

    private let provider: FileMetadataProvider
    /// Smart Name's reader, for renames from Shortcuts; the window reads
    /// through `analysis`.
    private let summarizer: DocumentSummarizer
    private let store: PersistenceStore
    /// The one thing that changes the user's files.
    private let mover: FileMover

    public init(
        provider: FileMetadataProvider = SystemFileMetadataProvider(),
        store: PersistenceStore = PersistenceStore(),
        summarizer: DocumentSummarizer = AppleIntelligenceSummarizer(),
        moveItem: @escaping (URL, URL) throws -> Void = {
            try FileManager.default.moveItem(at: $0, to: $1)
        }
    ) {
        self.provider = provider
        self.summarizer = summarizer
        self.store = store
        self.analysis = DocumentAnalysis(summarizer: summarizer)
        self.mover = FileMover(moveItem: moveItem)
        self.presets = store.loadPresets()
        self.history = store.loadHistory()
    }

    /// The step the panel is editing. Its kind is the function picker.
    public var step: FunctionSettings {
        get { steps[selectedStepIndex] }
        set { steps[selectedStepIndex] = newValue }
    }

    /// The chain's `RenameFunction`s, in order.
    public var functions: [RenameFunction] { steps.map(\.function) }

    /// Whether a step names files from their contents (Smart Name), so the
    /// files must be read.
    public var readsDocuments: Bool { steps.contains { $0.function.readsDocument } }

    /// Whether dragging rows changes anything: not while a step sorts the
    /// files itself, which would scramble the order behind the sorted view.
    public var allowsManualOrder: Bool { !steps.contains { $0.function.reordersItems } }

    /// The live plan, recomputed from the current files, function and options.
    public var plan: [PlannedRename] {
        let functions = functions
        return RenameEngine.plan(
            items: items, steps: functions, options: options,
            provider: planProvider(for: functions, documents: windowDocuments))
    }

    /// What Smart Name found for the window's files, keyed by where each is now.
    private var windowDocuments: [URL: DocumentSummary] {
        let summaries = analysis.summaries
        return Dictionary(
            items.compactMap { item in summaries[item.id].map { (item.url, $0) } },
            uniquingKeysWith: { first, _ in first })
    }

    /// The provider a plan reads, with what Smart Name found for each file
    /// in place of the disk read: a summary already carries its fallback date,
    /// so typing a template never goes to the disk — unless another step (a
    /// Date stamp, a date-sorted Sequence) reads the file's own dates too.
    private func planProvider(
        for functions: [RenameFunction], documents: @autoclosure () -> [URL: DocumentSummary]
    ) -> FileMetadataProvider {
        guard functions.contains(where: \.readsDocument) else { return provider }
        return SummarizedMetadataProvider(
            base: provider, documents: documents(), readsFiles: functions.contains(where: \.readsFileDates))
    }

    /// Read every file Smart Name hasn't yet — only while a step is Smart
    /// Name, so the model never runs for a rename that doesn't use it.
    /// Called as files arrive and Smart Name joins the steps, and when the app
    /// comes forward, which is when Apple Intelligence may have become ready.
    public func analyzeIfNeeded() {
        guard readsDocuments else { return }
        analysis.analyze(items)
    }

    /// Smart Name's progress for a row; nil when no step is Smart Name.
    public func readingStatus(for id: FileItem.ID) -> DocumentAnalysis.Status? {
        readsDocuments ? analysis.status[id] : nil
    }

    /// What Smart Name's details sheet starts from for a row: what was read,
    /// and the date a read falls back to, the file's own.
    public func documentDetails(for item: FileItem) -> (summary: DocumentSummary?, fileDate: Date?) {
        (analysis.summaries[item.id], provider.metadata(for: item.url).creationDate)
    }

    // MARK: - Steps

    /// The most steps a chain takes. A rename that needs more is better
    /// split into two, and five numbered steps still fit the narrowest window.
    public static let maxSteps = 5

    public var canAddStep: Bool { steps.count < Self.maxSteps }

    /// Add a step after the selected one, and edit it.
    public func addStep() {
        guard canAddStep else { return }
        steps.insert(FunctionSettings(), at: selectedStepIndex + 1)
        selectedStepIndex += 1
    }

    /// Remove the selected step; the last one left stays.
    public func removeSelectedStep() {
        guard steps.count > 1 else { return }
        steps.remove(at: selectedStepIndex)
    }

    /// Move the selected step one place earlier (`by: -1`) or later (`1`),
    /// keeping it selected.
    public func moveSelectedStep(by offset: Int) {
        let from = selectedStepIndex
        let to = from + offset
        guard steps.indices.contains(to) else { return }
        steps.swapAt(from, to)
        selectedStepIndex = to
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
        analyzeIfNeeded()
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
        analysis.forget(ids)
    }

    public func clear() {
        items.removeAll()
        selection.removeAll()
        analysis.cancelAll()
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
        renameFailures = commit(RenameEngine.actionableRenames(plan), undoManager: undoManager)
    }

    /// Move the planned rows' files, in an order that lets chains and swaps
    /// run, and record the batch in history. Returns what went wrong — empty
    /// when the whole batch succeeded.
    private func commit(_ actions: [PlannedRename], undoManager: UndoManager?) -> [String] {
        guard !actions.isEmpty else { return [] }
        let moves = actions.map { MoveOp(from: $0.url, to: $0.url.renamed(to: $0.proposedName)) }
        let failures = applyMoves(
            RenameSequencer.ordered(moves), undoManager: undoManager, actionName: "Rename")
        if failures.isEmpty {
            recordHistory(
                actions.map { HistoryEntry.Row(original: $0.originalName, renamed: $0.proposedName) })
        }
        return failures
    }

    // MARK: - Renaming from Shortcuts

    /// What a rename run from outside the window did.
    public struct OutsideRename: Sendable {
        /// Where each file is now, in the order given: renamed or not.
        public let files: [URL]
        /// The files left as they were, and why: one Smart Name couldn't
        /// read, a name that would collide.
        public let skipped: [String]
    }

    /// Rename `urls` with `steps`, as Shortcuts asks: the same plan, the same
    /// all-or-nothing moves and the same history as the Rename button, but
    /// not the window's files or settings, which stay as they are. Smart Name
    /// reads each file first. Throws when nothing could be renamed, the files
    /// couldn't be moved (none are), or Smart Name can't run on this Mac.
    public func rename(_ urls: [URL], steps: [RenameFunction], options: RenameOptions) async throws
        -> OutsideRename
    {
        let items = urls.map { FileItem(url: $0) }
        var documents: [URL: DocumentSummary] = [:]
        var skipped: [String] = []
        if steps.contains(where: \.readsDocument) {
            guard summarizer.availability == .available else {
                throw OutsideRenameError(summarizer.availability.explanation ?? "Smart Name can’t run.")
            }
            (documents, skipped) = await readDocuments(items)
        }
        let plan = RenameEngine.plan(
            items: items, steps: steps, options: options,
            provider: planProvider(for: steps, documents: documents))
        skipped += plan.compactMap { row in row.issue.map { "\(row.originalName): \($0.explanation)" } }
        let actions = RenameEngine.actionableRenames(plan)
        if actions.isEmpty, !skipped.isEmpty {
            throw OutsideRenameError("Nothing was renamed. " + skipped.joined(separator: " "))
        }
        let failures = commit(actions, undoManager: nil)
        guard failures.isEmpty else {
            throw OutsideRenameError(
                "Nothing was renamed. These couldn’t be moved: " + failures.joined(separator: ", "))
        }
        let renamed = Dictionary(
            uniqueKeysWithValues: actions.map { ($0.id, $0.url.renamed(to: $0.proposedName)) })
        return OutsideRename(files: items.map { renamed[$0.id] ?? $0.url }, skipped: skipped)
    }

    /// Read `items` for Smart Name through a queue of their own, the same as
    /// the window's (which gets a scan's text while the model answers for the
    /// file before), starting from what the window has read — or been told —
    /// for any of them. Returns what was found, and why the rest weren't.
    private func readDocuments(_ items: [FileItem]) async -> ([URL: DocumentSummary], [String]) {
        let reader = DocumentAnalysis(summarizer: summarizer)
        let known = windowDocuments
        for item in items {
            if let summary = known[item.url] { reader.correct(item.id, to: summary) }
        }
        reader.analyze(items)
        await reader.waitUntilIdle()
        var documents: [URL: DocumentSummary] = [:]
        var failures: [String] = []
        for item in items {
            if let summary = reader.summaries[item.id] {
                documents[item.url] = summary
            } else if case let .failed(reason) = reader.status[item.id] {
                failures.append("\(item.originalName): \(reason)")
            }
        }
        return (documents, failures)
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
    /// for undo. All-or-nothing (see `FileMover`). Returns what went wrong —
    /// empty when the whole batch succeeded; the table keeps pointing at each
    /// file's real location either way. `emptied` are folders an earlier batch
    /// made that this one (its undo) moves the files back out of: taken away
    /// once they're empty, so undoing a filing leaves no empty folders.
    private func applyMoves(
        _ moves: [MoveOp], undoManager: UndoManager?, actionName: String, emptied: [URL] = []
    ) -> [String] {
        let outcome = mover.run(moves)
        updateItemURLs(outcome.applied)
        guard outcome.failures.isEmpty else { return outcome.failures }
        mover.removeIfEmpty(emptied)
        guard !outcome.applied.isEmpty else { return [] }
        let inverse = outcome.applied.reversed().map { MoveOp(from: $0.to, to: $0.from) }
        let created = outcome.createdFolders
        undoManager?.registerUndo(withTarget: self) { model in
            // Surface any failure of the undo itself (e.g. a file moved or
            // deleted outside the app since) rather than failing silently.
            let failures = model.applyMoves(
                inverse, undoManager: undoManager, actionName: actionName, emptied: created)
            if !failures.isEmpty { model.renameFailures = failures }
        }
        undoManager?.setActionName(actionName)
        return []
    }

    /// Point the table at where the moves left each file, replayed in order
    /// (a cycle goes through a temporary name). Indexed once, not searched
    /// per move.
    private func updateItemURLs(_ moves: [MoveOp]) {
        var indexByURL = Dictionary(
            items.indices.map { (items[$0].url, $0) }, uniquingKeysWith: { first, _ in first })
        for move in moves {
            guard let index = indexByURL.removeValue(forKey: move.from) else { continue }
            items[index].url = move.to
            indexByURL[move.to] = index
        }
    }

    // MARK: - Presets

    public func saveCurrentAsPreset(named name: String) {
        presets.removeAll { $0.name == name }
        presets.append(Preset(name: name, steps: functions, options: options))
        store.savePresets(presets)
    }

    public func apply(_ preset: Preset) {
        guard !preset.steps.isEmpty else { return }
        options = preset.options
        selectedStepIndex = 0
        steps = preset.steps.map(FunctionSettings.init(loading:))
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
}

/// Smart Name's findings as file metadata. Unless another step needs the
/// file's own dates, this never asks the base provider (a disk and ImageIO
/// read per file).
private struct SummarizedMetadataProvider: FileMetadataProvider {
    let base: FileMetadataProvider
    let documents: [URL: DocumentSummary]
    let readsFiles: Bool

    func metadata(for url: URL) -> FileMetadata {
        var metadata = readsFiles ? base.metadata(for: url) : FileMetadata()
        metadata.document = documents[url]
        return metadata
    }

    func fileExists(at url: URL) -> Bool {
        base.fileExists(at: url)
    }
}

/// Why a rename from Shortcuts didn't happen, in words for the person.
struct OutsideRenameError: LocalizedError {
    public let errorDescription: String?

    init(_ description: String) {
        errorDescription = description
    }
}
