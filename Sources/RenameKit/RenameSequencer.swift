import Foundation

/// One file-move operation: move the file at `from` to `to`. Both are full URLs
/// in the same directory (a rename is a move within the parent folder).
public struct MoveOp: Equatable, Sendable {
    public let from: URL
    public let to: URL

    public init(from: URL, to: URL) {
        self.from = from
        self.to = to
    }
}

/// Orders a batch of renames so no move ever lands on a file that has not yet
/// moved out of the way, inserting moves through a temporary name to break
/// cycles — a swap (`a→b`, `b→a`) or a rotation (`a→b→c→a`). This is what lets
/// the app perform chained renames that a naive one-pass rename would refuse.
///
/// Pure: it performs no file-system access and simply returns the ordered move
/// list, so it is fully unit-tested. The caller executes the moves in order.
///
/// Precondition, guaranteed by `RenameEngine`'s collision check: destinations
/// are distinct, and any destination that is occupied on disk is the source of
/// another move in the batch (never an outside file that will not move). A
/// case-only move — `from` and `to` the same file on a case-insensitive volume
/// — is emitted directly, since the move renames the file in place.
public enum RenameSequencer {
    /// A hidden, unique sibling of `source` to park a file under while breaking
    /// a cycle — in the same directory so the move stays an on-volume rename,
    /// never a cross-device copy. This is the default `temporaryName`; tests
    /// inject a deterministic one.
    public static func temporaryName(for source: URL) -> URL {
        source.deletingLastPathComponent()
            .appending(component: ".filenamechanger-rename-\(UUID().uuidString).tmp")
    }

    public static func ordered(
        _ moves: [MoveOp], temporaryName: (URL) -> URL = temporaryName
    ) -> [MoveOp] {
        func key(_ url: URL) -> String { url.caseFoldedPathKey }

        // Every source currently holds a file; a destination is free to move
        // onto only once it is no longer in this set.
        var occupied = Set(moves.map { key($0.from) })
        var pending = moves
        var result: [MoveOp] = []

        while !pending.isEmpty {
            if let index = pending.firstIndex(where: {
                key($0.to) == key($0.from) || !occupied.contains(key($0.to))
            }) {
                let move = pending.remove(at: index)
                result.append(move)
                occupied.remove(key(move.from))  // source vacated
                occupied.insert(key(move.to))  // destination now holds the file
            } else {
                // Every remaining destination is still occupied: a cycle. Park
                // one file under a temporary name to free its source; the move
                // waiting on that source can then proceed, and the parked file
                // reaches its destination once that is vacated in turn.
                let stuck = pending[0]
                let temp = temporaryName(stuck.from)
                result.append(MoveOp(from: stuck.from, to: temp))
                occupied.remove(key(stuck.from))
                occupied.insert(key(temp))
                pending[0] = MoveOp(from: temp, to: stuck.to)
            }
        }
        return result
    }
}
