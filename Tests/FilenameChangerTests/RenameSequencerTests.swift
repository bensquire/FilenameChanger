import Foundation
import Testing

@testable import RenameKit

/// The pure ordering of a rename batch: shifts need only reordering, cycles
/// (swaps, rotations) need a move through a temporary name. No file system.
@Suite("RenameSequencer: safe ordering of chained renames")
struct RenameSequencerTests {
    private let dir = URL(fileURLWithPath: "/d")
    private func u(_ name: String) -> URL { dir.appendingPathComponent(name) }
    private func op(_ from: String, _ to: String) -> MoveOp {
        MoveOp(from: u(from), to: u(to))
    }
    /// A deterministic temp name so the expected sequence is stable.
    private func ordered(_ moves: [MoveOp]) -> [MoveOp] {
        var counter = 0
        return RenameSequencer.ordered(moves) { _ in
            defer { counter += 1 }
            return self.u("TMP\(counter)")
        }
    }

    @Test("independent renames keep their order, no temp")
    func independent() {
        #expect(ordered([op("a", "x"), op("b", "y")]) == [op("a", "x"), op("b", "y")])
    }

    @Test("a shift runs tail-first so nothing is overwritten")
    func shift() {
        // 1→2, 2→3, 3→4 must run 3→4, 2→3, 1→2.
        #expect(
            ordered([op("1", "2"), op("2", "3"), op("3", "4")])
                == [op("3", "4"), op("2", "3"), op("1", "2")])
    }

    @Test("a swap parks one file under a temp name")
    func swap() {
        #expect(
            ordered([op("a", "b"), op("b", "a")])
                == [op("a", "TMP0"), op("b", "a"), op("TMP0", "b")])
    }

    @Test("a three-way rotation parks one file and unwinds")
    func rotation() {
        #expect(
            ordered([op("a", "b"), op("b", "c"), op("c", "a")])
                == [op("a", "TMP0"), op("c", "a"), op("b", "c"), op("TMP0", "b")])
    }

    @Test("a case-only move is emitted directly, no temp")
    func caseOnly() {
        #expect(ordered([op("photo", "PHOTO")]) == [op("photo", "PHOTO")])
    }

    @Test("an empty batch orders to nothing")
    func empty() {
        #expect(ordered([]) == [])
    }
}
