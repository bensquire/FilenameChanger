import Foundation
import RenameKit

/// Carries out an ordered batch of moves, all or nothing: on the first failure
/// every completed move is put back. The one place the user's files change.
///
/// A move into a folder that isn't there yet (Smart Name filing into
/// "{from}/…") makes the folder first. The folders a batch made are reported,
/// so whoever undoes the batch can take them away again once they're empty.
struct FileMover {
    /// What a batch did.
    struct Outcome {
        /// Every move that happened, in order, including any that put a file
        /// back after a failure — replay them to know where each file is now.
        var applied: [MoveOp] = []
        /// What went wrong: the name that couldn't be written, and any file a
        /// rollback couldn't put back. Empty when the whole batch succeeded.
        var failures: [String] = []
        /// Folders made for this batch, outermost first. Empty after a failure,
        /// which takes them away again.
        var createdFolders: [URL] = []
    }

    /// `FileManager.moveItem` never overwrites; injected so tests can make a
    /// move fail on demand.
    /// /documentation/foundation/filemanager/moveitem(at:to:)
    let moveItem: (URL, URL) throws -> Void

    func run(_ moves: [MoveOp]) -> Outcome {
        var outcome = Outcome()
        for move in moves {
            do {
                try makeFolders(for: move.to, recordingIn: &outcome.createdFolders)
                try moveItem(move.from, move.to)
                outcome.applied.append(move)
            } catch {
                outcome.failures = [move.to.lastPathComponent]
                // Undo the completed moves, newest first, back to the start. A
                // rollback move can itself fail (a file locked or deleted
                // outside the app): that file stays where it is, possibly under
                // a temporary name from a half-finished cycle, and the message
                // says where it was left.
                // The moves made so far; putting them back appends to `applied`.
                let made = outcome.applied
                for completed in made.reversed() {
                    let back = MoveOp(from: completed.to, to: completed.from)
                    do {
                        try moveItem(back.from, back.to)
                        outcome.applied.append(back)
                    } catch {
                        outcome.failures.append(
                            "\(completed.from.lastPathComponent) (left as \(completed.to.lastPathComponent))")
                    }
                }
                removeIfEmpty(outcome.createdFolders)
                outcome.createdFolders = []
                return outcome
            }
        }
        return outcome
    }

    /// Take away folders a batch made, innermost first, if nothing is left in
    /// them. One the user has since put something in stays.
    func removeIfEmpty(_ folders: [URL]) {
        let files = FileManager.default
        for folder in folders.reversed() {
            guard let contents = try? files.contentsOfDirectory(atPath: folder.path(percentEncoded: false)),
                contents.isEmpty
            else { continue }
            try? files.removeItem(at: folder)
        }
    }

    /// Make the folders `destination` sits in that don't exist yet, one level
    /// at a time, adding each to `made` (outermost first) as it is made, so a
    /// failure partway still knows what to take away.
    /// /documentation/foundation/filemanager/createdirectory(at:withintermediatedirectories:attributes:)
    private func makeFolders(for destination: URL, recordingIn made: inout [URL]) throws {
        var missing: [URL] = []
        var folder = destination.deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: folder.path(percentEncoded: false)) {
            missing.insert(folder, at: 0)
            folder = folder.deletingLastPathComponent()
        }
        for folder in missing {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
            made.append(folder)
        }
    }
}
