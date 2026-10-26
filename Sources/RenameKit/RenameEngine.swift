import Foundation

/// Turns a list of files plus a chosen function and options into a plan: the
/// name each file would take, whether it would change, and any issue blocking
/// it. Pure — all file-system knowledge comes through the injected provider —
/// so the whole of it is unit-tested.
public enum RenameEngine {
    /// Build the plan for one function: a chain of one step.
    public static func plan(
        items: [FileItem],
        function: RenameFunction,
        options: RenameOptions,
        provider: FileMetadataProvider
    ) -> [PlannedRename] {
        plan(items: items, steps: [function], options: options, provider: provider)
    }

    /// Build the plan. Rows come back in working order (a sequence sort
    /// reorders them); each row carries the id of its source `FileItem`.
    ///
    /// The steps run in order, each on the name the one before it left: Smart
    /// Name, then Clean Up, then Change Case. A step that doesn't match a row
    /// (a Replace with nothing to find) leaves the name as it is for the next
    /// step, so a row is skipped only when the chain changes nothing.
    public static func plan(
        items: [FileItem],
        steps: [RenameFunction],
        options: RenameOptions,
        provider: FileMetadataProvider
    ) -> [PlannedRename] {
        // Metadata is a disk + ImageIO read per file, and the plan reruns on
        // every keystroke: read only when a step uses it, and once per file,
        // shared by a Sequence's sort and the names.
        let readsMetadata = steps.contains(where: \.readsMetadata)
        var metadataCache: [UUID: FileMetadata] = [:]
        func metadata(for item: FileItem) -> FileMetadata {
            guard readsMetadata else { return FileMetadata() }
            if let cached = metadataCache[item.id] { return cached }
            let read = provider.metadata(for: item.url)
            metadataCache[item.id] = read
            return read
        }

        // Only Sequence reorders; with two, the later sort numbers both.
        let working = steps.reduce(items) { items, step in step.order(items, metadata: metadata) }

        // Pass one: the proposed name for each row that changes, and which of
        // those can't be a name. `sequenceIndex` counts only enabled rows, so
        // Sequence numbering has no gaps when a row is unchecked.
        var proposedNames: [UUID: String] = [:]
        var invalid: Set<UUID> = []
        var sequenceIndex = 0
        for item in working {
            guard item.isEnabled else { continue }
            let context = ItemContext(index: sequenceIndex, metadata: metadata(for: item), options: options)
            sequenceIndex += 1
            guard let proposal = chainedName(item.originalName, steps: steps, context: context) else {
                continue
            }
            if proposal.path != item.originalName {
                proposedNames[item.id] = proposal.path
                if !proposal.isValid { invalid.insert(item.id) }
            }
        }

        if options.forceUnique {
            // The destination keys of enabled rows' current files: a target
            // matching one is a file the batch itself is moving, not an outside
            // collision. Force Unique resolves these by numbering instead.
            let batchSources = Set(working.filter(\.isEnabled).map { $0.url.caseFoldedPathKey })
            return planForcingUnique(
                working: working, proposedNames: proposedNames, invalid: invalid,
                batchSources: batchSources, provider: provider)
        }
        return planFlaggingCollisions(
            working: working, proposedNames: proposedNames, invalid: invalid, provider: provider)
    }

    /// Rows that will actually be renamed, in the order they should run.
    public static func actionableRenames(_ plan: [PlannedRename]) -> [PlannedRename] {
        plan.filter { $0.willRename && $0.issue == nil }
    }

    /// Plan one explicit rename of `item` to `name` (the whole final name,
    /// extension included) — the inline single-file rename path. Reuses the
    /// batch plan's validation and collision rules, through the injected
    /// provider, so there is a single authority for what counts as a collision.
    public static func planOverride(
        name: String, for item: FileItem, provider: FileMetadataProvider
    ) -> PlannedRename {
        guard name != item.originalName else {
            return row(item, proposedName: name, willRename: false, issue: nil)
        }
        if let issue = validate(name) {
            return row(item, proposedName: name, willRename: false, issue: issue)
        }
        if !isAvailable(name, for: item, batchSources: [], provider: provider) {
            return row(item, proposedName: name, willRename: false, issue: .collision)
        }
        return row(item, proposedName: name, willRename: true, issue: nil)
    }

    // MARK: - Collision strategies

    private static func planFlaggingCollisions(
        working: [FileItem], proposedNames: [UUID: String], invalid: Set<UUID>,
        provider: FileMetadataProvider
    ) -> [PlannedRename] {
        // Per proposed row: its destination key, how many rows want that key,
        // and whether a file is already on disk there. Keys are the full
        // destination path, case-folded, so two files in different folders
        // don't false-collide and two that differ only in case (the same file
        // on a case-insensitive volume) do. Disk existence is read once here,
        // not inside the fix-point loop below.
        var destinationKeys: [UUID: String] = [:]
        var destinationCounts: [String: Int] = [:]
        var existsOnDisk: [UUID: Bool] = [:]
        for item in working {
            guard let name = proposedNames[item.id] else { continue }
            let key = collisionKey(for: item, name: name)
            destinationKeys[item.id] = key
            destinationCounts[key, default: 0] += 1
            existsOnDisk[item.id] = provider.fileExists(at: targetURL(for: item, name: name))
        }

        // A row's issue that doesn't depend on move ordering — an invalid name,
        // or two rows wanting the same destination — computed once up front.
        var staticIssues: [UUID: RenameIssue] = [:]
        for item in working {
            guard let key = destinationKeys[item.id] else { continue }
            if invalid.contains(item.id) {
                staticIssues[item.id] = .invalidName
            } else if destinationCounts[key, default: 0] > 1 {
                staticIssues[item.id] = .duplicateResult
            }
        }

        // The remaining rows are "movers" whose source vacates if they run. A
        // mover is a genuine collision only when its destination is occupied on
        // disk by a file that no surviving mover will move away — nothing in the
        // batch frees it. Blocking one mover removes its source from the pool,
        // which can block another, so iterate to a fix-point; since blocking
        // only shrinks `surviving`, it converges to the same set in any order.
        // (Chains and cycles resolve fine: their occupants are all movers.)
        let movers = working.filter { proposedNames[$0.id] != nil && staticIssues[$0.id] == nil }
        var surviving = Set(movers.map { $0.url.caseFoldedPathKey })
        var blocked: Set<UUID> = []
        var changed = true
        while changed {
            changed = false
            for item in movers where !blocked.contains(item.id) {
                guard let destinationKey = destinationKeys[item.id] else { continue }
                if destinationKey == item.url.caseFoldedPathKey { continue }  // case-only move onto self
                if existsOnDisk[item.id] == true, !surviving.contains(destinationKey) {
                    blocked.insert(item.id)
                    surviving.remove(item.url.caseFoldedPathKey)
                    changed = true
                }
            }
        }

        return working.map { item in
            guard let name = proposedNames[item.id] else { return unchanged(item) }
            if let issue = staticIssues[item.id] {
                return row(item, proposedName: name, willRename: false, issue: issue)
            }
            if blocked.contains(item.id) {
                return row(item, proposedName: name, willRename: false, issue: .collision)
            }
            return row(item, proposedName: name, willRename: true, issue: nil)
        }
    }

    private static func planForcingUnique(
        working: [FileItem], proposedNames: [UUID: String], invalid: Set<UUID>,
        batchSources: Set<String>, provider: FileMetadataProvider
    ) -> [PlannedRename] {
        var taken: Set<String> = []
        return working.map { item in
            guard let name = proposedNames[item.id] else {
                return unchanged(item)
            }
            if invalid.contains(item.id) {
                return row(item, proposedName: name, willRename: false, issue: .invalidName)
            }
            let unique = makeUnique(
                name, taken: &taken, item: item, batchSources: batchSources, provider: provider)
            return row(item, proposedName: unique, willRename: unique != item.originalName, issue: nil)
        }
    }

    // MARK: - Helpers

    /// What a chain makes of a file's name: folders to file it into (from a
    /// step that makes them), and the name itself.
    private struct Proposal {
        var folders: [String] = []
        var name: String

        /// The name relative to the file's folder: "Acme Energy/Bill.pdf".
        var path: String { (folders + [name]).joined(separator: "/") }

        /// The name passes `validate`, and each folder is a proper name too —
        /// not empty (a leading "/" would be the disk's root), "." or "..", or
        /// hidden. Under a folder, a hidden file ("Bills/.pdf") is refused too.
        var isValid: Bool {
            guard validate(name) == nil else { return false }
            return folders.allSatisfy { folder in
                !folder.trimmingCharacters(in: .whitespaces).isEmpty && folder != ".."
                    && !folder.hasPrefix(".")
            } && (folders.isEmpty || !name.hasPrefix("."))
        }
    }

    /// The name `steps` make of `name`, or nil to hold the row back: a step
    /// still waiting on what it reads (Smart Name before the file is read)
    /// mustn't let the rest of the chain rename it without that step's part.
    /// The folders a step files into are set apart as it makes them, so the
    /// steps after it work on the name alone, and a "/" any other step makes
    /// stays an invalid name.
    private static func chainedName(_ name: String, steps: [RenameFunction], context: ItemContext)
        -> Proposal?
    {
        var proposal = Proposal(name: name)
        for step in steps {
            if step.isWaiting(for: context.metadata) { return nil }
            // Some functions (the word-splitting Change Case styles, Smart
            // Name) must never touch the extension, even when Hide Extensions
            // is off.
            let hidesExtension = context.options.hideExtension || step.preservesExtension
            let (base, ext) = split(proposal.name, hideExtension: hidesExtension)
            guard var newBase = step.proposedBaseName(for: base, context: context) else { continue }
            if step.makesFolders {
                var parts = newBase.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
                newBase = parts.removeLast()
                proposal.folders += parts
            }
            // A base emptied (or left as only spaces) would rejoin as a bare
            // ".ext" — a hidden dotfile that seems to vanish. Propose an empty
            // name instead, which `validate` flags: one rule for every function.
            guard !newBase.trimmingCharacters(in: .whitespaces).isEmpty else {
                proposal.name = ""
                return proposal
            }
            proposal.name = join(base: newBase, ext: ext, hideExtension: hidesExtension)
        }
        return proposal
    }

    /// Build one plan row, copying the stable fields straight off the item so
    /// each call site only states what varies.
    private static func row(
        _ item: FileItem, proposedName: String, willRename: Bool, issue: RenameIssue?
    ) -> PlannedRename {
        PlannedRename(
            id: item.id, url: item.url, originalName: item.originalName,
            isEnabled: item.isEnabled, proposedName: proposedName,
            willRename: willRename, issue: issue)
    }

    private static func unchanged(_ item: FileItem) -> PlannedRename {
        row(item, proposedName: item.originalName, willRename: false, issue: nil)
    }

    private static func validate(_ name: String) -> RenameIssue? {
        // Empty or only spaces, the current/parent directory, or a path
        // separator: not a renamable file name.
        let blank = name.trimmingCharacters(in: .whitespaces).isEmpty
        return blank || name == "." || name == ".." || name.contains("/") ? .invalidName : nil
    }

    /// Renaming a file to a case variant of its own name (e.g. Change Case) is
    /// not a collision, even though a case-insensitive file system reports the
    /// target as already existing — that match is the file itself.
    private static func refersToItself(_ name: String, _ item: FileItem) -> Bool {
        name.caseInsensitiveCompare(item.originalName) == .orderedSame
    }

    /// Whether `name` is free for `item`: the file's own name, or a destination
    /// no other row in the batch claims and nothing on disk holds.
    private static func isAvailable(
        _ name: String, for item: FileItem, batchSources: Set<String>,
        provider: FileMetadataProvider
    ) -> Bool {
        if refersToItself(name, item) { return true }
        guard !batchSources.contains(collisionKey(for: item, name: name)) else { return false }
        return !provider.fileExists(at: targetURL(for: item, name: name))
    }

    /// Append " 1", " 2"… before the extension until the name is free, both
    /// in the batch so far and on disk.
    private static func makeUnique(
        _ name: String, taken: inout Set<String>, item: FileItem,
        batchSources: Set<String>, provider: FileMetadataProvider
    ) -> String {
        func isFree(_ candidate: String) -> Bool {
            !taken.contains(collisionKey(for: item, name: candidate))
                && isAvailable(candidate, for: item, batchSources: batchSources, provider: provider)
        }
        if isFree(name) {
            taken.insert(collisionKey(for: item, name: name))
            return name
        }
        let (base, ext) = split(name, hideExtension: true)
        var counter = 1
        while true {
            let candidate = join(base: "\(base) \(counter)", ext: ext, hideExtension: true)
            if isFree(candidate) {
                taken.insert(collisionKey(for: item, name: candidate))
                return candidate
            }
            counter += 1
        }
    }

    private static func targetURL(for item: FileItem, name: String) -> URL {
        item.url.renamed(to: name)
    }

    /// The key used to compare renames for collisions: the full destination
    /// path, case-folded. Case-folding assumes the common case-insensitive
    /// macOS volume, where names differing only in case are the same file.
    private static func collisionKey(for item: FileItem, name: String) -> String {
        targetURL(for: item, name: name).caseFoldedPathKey
    }

    private static func split(_ name: String, hideExtension: Bool) -> (base: String, ext: String) {
        guard hideExtension else { return (name, "") }
        let ns = name as NSString
        return (ns.deletingPathExtension, ns.pathExtension)
    }

    private static func join(base: String, ext: String, hideExtension: Bool) -> String {
        guard hideExtension, !ext.isEmpty else { return base }
        return "\(base).\(ext)"
    }
}
