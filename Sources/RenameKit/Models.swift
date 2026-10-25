import Foundation

/// A file queued for renaming. Identity is a stable id so the table and the
/// plan can refer to the same row even as the name or position changes.
public struct FileItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var url: URL
    /// The left-edge checkbox: an unchecked row is skipped by the rename.
    public var isEnabled: Bool

    public init(url: URL, isEnabled: Bool = true, id: UUID = UUID()) {
        self.id = id
        self.url = url
        self.isEnabled = isEnabled
    }

    public var originalName: String { url.lastPathComponent }
}

/// The three cross-cutting switches from the original's Options menu.
public struct RenameOptions: Sendable, Equatable, Codable {
    /// Operate on the name without its extension, leaving the extension intact.
    public var hideExtension: Bool
    /// Case-insensitive matching for the replace and wildcard functions.
    public var ignoreCase: Bool
    /// Resolve names that would collide within the batch by appending " 1",
    /// " 2"… before the extension, rather than flagging them.
    public var forceUnique: Bool

    public init(hideExtension: Bool = false, ignoreCase: Bool = false, forceUnique: Bool = false) {
        self.hideExtension = hideExtension
        self.ignoreCase = ignoreCase
        self.forceUnique = forceUnique
    }

    /// The name as it should appear in the table: with its extension stripped
    /// when Hide Extensions is on. The extension is only hidden, never removed —
    /// the real file keeps it — so this is a presentation concern.
    public func displayName(for name: String) -> String {
        hideExtension ? (name as NSString).deletingPathExtension : name
    }
}

/// Metadata a function may need, read once per file and injected so tests
/// stay off the clock and the disk.
public struct FileMetadata: Sendable, Equatable {
    public var creationDate: Date?
    public var modificationDate: Date?
    public var exifDate: Date?
    /// What reading the file's contents found, for Smart Name. Nil until the
    /// file has been read — reading is slow, so it happens outside the plan.
    public var document: DocumentSummary?

    public init(
        creationDate: Date? = nil, modificationDate: Date? = nil, exifDate: Date? = nil,
        document: DocumentSummary? = nil
    ) {
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.exifDate = exifDate
        self.document = document
    }
}

/// A document's title, who it is from, and its date (the date it was issued
/// or written), as read from its contents.
public struct DocumentSummary: Sendable, Equatable {
    public var title: String
    /// The company, organisation or person that sent or issued it; nil when
    /// the document doesn't say.
    public var from: String?
    /// The date the document gives, or the file's creation date when it gives
    /// none (decided when it is read, so the plan never goes to the disk).
    /// Nil only when neither exists.
    public var date: Date?

    public init(title: String, from: String? = nil, date: Date? = nil) {
        self.title = title
        self.from = from
        self.date = date
    }
}

/// Supplies per-file metadata and answers whether a target name is already
/// taken on disk. The real implementation reads the file system; tests pass
/// a fake. See `SystemFileMetadataProvider`.
public protocol FileMetadataProvider: Sendable {
    func metadata(for url: URL) -> FileMetadata
    /// True when a file already exists at `url` (used to flag collisions with
    /// files outside the batch).
    func fileExists(at url: URL) -> Bool
}

/// Why a row cannot be renamed — the original's "grey rows".
public enum RenameIssue: Sendable, Equatable {
    /// Another file already exists with the proposed name.
    case collision
    /// Two rows in the batch resolve to the same name.
    case duplicateResult
    /// The proposed name is empty or contains a path separator.
    case invalidName
}

/// One row of the engine's output: the name a file would take, whether it
/// would actually change, and any issue blocking it.
public struct PlannedRename: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let url: URL
    public let originalName: String
    /// Mirrors the source `FileItem`'s checkbox, so the table can draw the row
    /// without scanning the item list for each row.
    public let isEnabled: Bool
    public let proposedName: String
    /// False when the row is skipped: disabled, no match, unchanged, or blocked
    /// by an issue.
    public let willRename: Bool
    public let issue: RenameIssue?

    public init(
        id: UUID, url: URL, originalName: String, isEnabled: Bool, proposedName: String,
        willRename: Bool, issue: RenameIssue?
    ) {
        self.id = id
        self.url = url
        self.originalName = originalName
        self.isEnabled = isEnabled
        self.proposedName = proposedName
        self.willRename = willRename
        self.issue = issue
    }
}

/// Where a generated string (sequence or date) is placed relative to the name.
public enum Placement: String, Sendable, CaseIterable, Codable {
    case prepend
    case append
    case replaceAll
}

extension URL {
    /// A case-folded full-path key: on a case-insensitive volume, two URLs with
    /// the same key are the same file. This is the single collision rule the
    /// `RenameEngine` (what counts as a clash) and the `RenameSequencer` (what
    /// counts as occupied) both rely on, so they can never drift apart.
    var caseFoldedPathKey: String { filePath.lowercased() }

    /// The decoded file-system path, without the trailing "/" a directory URL
    /// carries: a package found by a folder walk ("Foo.app/") and a rename
    /// target built from its name ("Foo.app") are the same path. The older
    /// `path` dropped it; its replacement keeps it.
    /// /documentation/foundation/url/path(percentencoded:)
    var filePath: String {
        let path = path(percentEncoded: false)
        return path != "/" && path.hasSuffix("/") ? String(path.dropLast()) : path
    }

    /// Where the file at this URL lands when renamed to `name`: a sibling in
    /// the same folder. The one definition both the plan's collision checks
    /// and the move itself use. Built from the name alone, as
    /// `appendingPathComponent` may touch the disk to check for a folder.
    /// /documentation/foundation/url/appendingpathcomponent(_:)
    public func renamed(to name: String) -> URL {
        deletingLastPathComponent().appending(component: name)
    }
}
