import Foundation
import Testing

@testable import RenameApp
@testable import RenameKit

/// End-to-end tests of the real Rename-button path: `AppModel.performRename`
/// moving actual files on disk via the default `SystemFileMetadataProvider`,
/// and ⌘Z undoing the whole batch. The function-level suites use a fake that
/// never touches the file system; these do, so the `FileManager.moveItem` and
/// `UndoManager` wiring is covered too.
@MainActor
@Suite("Rename on disk: performRename + undo")
struct RenameOnDiskTests {
    /// A fresh temp directory holding real, empty files; removed on deinit.
    private final class Sandbox {
        let directory: URL
        init(_ names: [String]) throws {
            directory = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("fnc-disk-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for name in names {
                FileManager.default.createFile(
                    atPath: directory.appendingPathComponent(name).path, contents: Data())
            }
        }
        func urls(_ names: [String]) -> [URL] { names.map { directory.appendingPathComponent($0) } }
        func exists(_ name: String) -> Bool {
            FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path)
        }
        /// Write distinctive bytes into a file so a test can prove its content
        /// survived (or wasn't clobbered by) a rename.
        func write(_ content: String, to name: String) {
            try? Data(content.utf8).write(to: directory.appendingPathComponent(name))
        }
        func contents(of name: String) -> String? {
            try? String(contentsOf: directory.appendingPathComponent(name), encoding: .utf8)
        }
        deinit { try? FileManager.default.removeItem(at: directory) }
    }

    private func makeModel(in directory: URL) -> AppModel {
        let store = PersistenceStore(
            directory: directory.appendingPathComponent("store-\(UUID().uuidString)"))
        return AppModel(store: store)  // real SystemFileMetadataProvider
    }

    @Test("Prepend actually renames the files on disk")
    func performRenameMovesFiles() throws {
        // Arrange: three real files, a model pointed at them, Prepend "2026-".
        let sandbox = try Sandbox(["a.txt", "b.txt", "c.txt"])
        let model = makeModel(in: sandbox.directory)
        model.add(urls: sandbox.urls(["a.txt", "b.txt", "c.txt"]))
        model.kind = .prepend
        model.prependText = "2026-"

        // Act
        model.performRename(undoManager: nil)

        // Assert: new names on disk, old names gone, and the table's URLs moved.
        for name in ["2026-a.txt", "2026-b.txt", "2026-c.txt"] {
            #expect(sandbox.exists(name))
        }
        for name in ["a.txt", "b.txt", "c.txt"] {
            #expect(!sandbox.exists(name))
        }
        #expect(model.items.map(\.originalName) == ["2026-a.txt", "2026-b.txt", "2026-c.txt"])
        #expect(model.history.first?.rows.count == 3)
    }

    @Test("Undo moves the whole batch back")
    func undoRestoresOriginalNames() throws {
        let sandbox = try Sandbox(["a.txt", "b.txt"])
        let model = makeModel(in: sandbox.directory)
        model.add(urls: sandbox.urls(["a.txt", "b.txt"]))
        model.kind = .prepend
        model.prependText = "x-"
        let undo = UndoManager()

        model.performRename(undoManager: undo)
        #expect(sandbox.exists("x-a.txt") && !sandbox.exists("a.txt"))

        undo.undo()

        #expect(sandbox.exists("a.txt") && sandbox.exists("b.txt"))
        #expect(!sandbox.exists("x-a.txt") && !sandbox.exists("x-b.txt"))
        #expect(model.items.map(\.originalName) == ["a.txt", "b.txt"])

        // Redo re-applies the batch.
        undo.redo()
        #expect(sandbox.exists("x-a.txt") && sandbox.exists("x-b.txt"))
        #expect(model.items.map(\.originalName) == ["x-a.txt", "x-b.txt"])
    }

    @Test("renameSingle renames one file and records history")
    func renameSingleMovesOneFile() throws {
        let sandbox = try Sandbox(["a.txt", "b.txt"])
        let model = makeModel(in: sandbox.directory)
        model.add(urls: sandbox.urls(["a.txt", "b.txt"]))
        let id = model.items[0].id

        let ok = model.renameSingle(id, to: "renamed.txt", undoManager: nil)

        #expect(ok)
        #expect(sandbox.exists("renamed.txt") && !sandbox.exists("a.txt"))
        #expect(sandbox.exists("b.txt"))
        #expect(model.items.map(\.originalName) == ["renamed.txt", "b.txt"])
        #expect(model.history.first?.rows.first?.renamed == "renamed.txt")
    }

    @Test("renameSingle refuses a name that is already taken")
    func renameSingleRefusesCollision() throws {
        let sandbox = try Sandbox(["a.txt", "b.txt"])
        let model = makeModel(in: sandbox.directory)
        model.add(urls: sandbox.urls(["a.txt"]))

        let ok = model.renameSingle(model.items[0].id, to: "b.txt", undoManager: nil)

        #expect(!ok)
        #expect(model.renameFailures == ["b.txt"])
        #expect(sandbox.exists("a.txt") && sandbox.exists("b.txt"))
    }

    @Test("renameSingle refuses an invalid name and reports it")
    func renameSingleRefusesInvalid() throws {
        let sandbox = try Sandbox(["a.txt"])
        let model = makeModel(in: sandbox.directory)
        model.add(urls: sandbox.urls(["a.txt"]))

        let ok = model.renameSingle(model.items[0].id, to: "a/b.txt", undoManager: nil)

        #expect(!ok)
        #expect(model.renameFailures == ["a/b.txt"])
        #expect(sandbox.exists("a.txt"))
    }

    @Test("a row blocked by a collision is left on disk untouched")
    func blockedRowIsNotMoved() throws {
        // "report.txt" already exists, so renaming draft → report must be skipped;
        // both files stay as they are.
        let sandbox = try Sandbox(["draft.txt", "report.txt"])
        let model = makeModel(in: sandbox.directory)
        model.add(urls: sandbox.urls(["draft.txt"]))
        model.kind = .replaceFirst
        model.findText = "draft"
        model.replaceText = "report"

        model.performRename(undoManager: nil)

        #expect(sandbox.exists("draft.txt"))
        #expect(sandbox.exists("report.txt"))
        #expect(model.history.isEmpty)
    }

    @Test("a collision never overwrites the existing file's contents")
    func collisionDoesNotClobberContents() throws {
        // Data-integrity guarantee: renaming onto an existing name is refused by
        // FileManager.moveItem (it never overwrites), so the target keeps its
        // bytes and the source keeps its own.
        let sandbox = try Sandbox(["draft.txt", "report.txt"])
        sandbox.write("SOURCE", to: "draft.txt")
        sandbox.write("PRECIOUS", to: "report.txt")
        let model = makeModel(in: sandbox.directory)
        model.add(urls: sandbox.urls(["draft.txt"]))
        model.kind = .replaceFirst
        model.findText = "draft"
        model.replaceText = "report"

        model.performRename(undoManager: nil)

        #expect(sandbox.contents(of: "report.txt") == "PRECIOUS")  // untouched
        #expect(sandbox.contents(of: "draft.txt") == "SOURCE")  // not moved
    }

    @Test("a swap renames both files through a temp, content intact")
    func swapRenamesBothFiles() throws {
        // Table order [2.txt, 1.txt] renumbered from 1 swaps the two names. The
        // executor must route one file through a temp so neither is clobbered.
        let sandbox = try Sandbox(["2.txt", "1.txt"])
        sandbox.write("TWO", to: "2.txt")
        sandbox.write("ONE", to: "1.txt")
        let model = makeModel(in: sandbox.directory)
        model.add(urls: sandbox.urls(["2.txt", "1.txt"]))
        model.kind = .sequence
        model.sequence = SequenceConfig(placement: .replaceAll, digits: 1, start: 1, sort: .custom)

        model.performRename(undoManager: nil)

        #expect(model.renameFailures.isEmpty)
        #expect(sandbox.contents(of: "1.txt") == "TWO")  // old 2.txt's bytes
        #expect(sandbox.contents(of: "2.txt") == "ONE")  // old 1.txt's bytes
        // No temp files left behind.
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: sandbox.directory.path)
            .filter { $0.hasPrefix(".filenamechanger-rename") }
        #expect(leftovers.isEmpty)
    }

    @Test("a shift renumber preserves every file's content")
    func shiftRenumberPreservesContent() throws {
        let sandbox = try Sandbox(["1.txt", "2.txt", "3.txt"])
        sandbox.write("A", to: "1.txt")
        sandbox.write("B", to: "2.txt")
        sandbox.write("C", to: "3.txt")
        let model = makeModel(in: sandbox.directory)
        model.add(urls: sandbox.urls(["1.txt", "2.txt", "3.txt"]))
        model.kind = .sequence
        model.sequence = SequenceConfig(placement: .replaceAll, digits: 1, start: 2, sort: .custom)

        model.performRename(undoManager: nil)

        #expect(model.renameFailures.isEmpty)
        #expect(!sandbox.exists("1.txt"))
        #expect(sandbox.contents(of: "2.txt") == "A")
        #expect(sandbox.contents(of: "3.txt") == "B")
        #expect(sandbox.contents(of: "4.txt") == "C")
    }

    @Test("undo of a swap restores the original names and content")
    func undoSwap() throws {
        let sandbox = try Sandbox(["2.txt", "1.txt"])
        sandbox.write("TWO", to: "2.txt")
        sandbox.write("ONE", to: "1.txt")
        let model = makeModel(in: sandbox.directory)
        model.add(urls: sandbox.urls(["2.txt", "1.txt"]))
        model.kind = .sequence
        model.sequence = SequenceConfig(placement: .replaceAll, digits: 1, start: 1, sort: .custom)
        let undo = UndoManager()

        model.performRename(undoManager: undo)
        #expect(sandbox.contents(of: "1.txt") == "TWO")  // swapped

        undo.undo()

        #expect(sandbox.contents(of: "1.txt") == "ONE")  // restored
        #expect(sandbox.contents(of: "2.txt") == "TWO")
    }

    @Test("a case-only rename succeeds and preserves the file")
    func caseOnlyRenamePreservesFile() throws {
        // Change Case to a case variant is a rename to a name a case-insensitive
        // volume already "has" (the file itself). It must still rename, not fail
        // or lose the file.
        let sandbox = try Sandbox(["photo.txt"])
        sandbox.write("PIXELS", to: "photo.txt")
        let model = makeModel(in: sandbox.directory)
        model.add(urls: sandbox.urls(["photo.txt"]))
        model.kind = .changeCase
        model.textCase = .upper

        model.performRename(undoManager: nil)

        #expect(model.items.map(\.originalName) == ["PHOTO.txt"])
        #expect(sandbox.contents(of: "PHOTO.txt") == "PIXELS")
        #expect(model.renameFailures.isEmpty)
    }

    @Test("a rollback that can't finish says where the file was left")
    func failedRollbackIsReported() throws {
        // Arrange: Prepend over a.txt and b.txt. The injected mover lets a's
        // move through, then fails b's (forcing a rollback) and a's move back.
        let sandbox = try Sandbox(["a.txt", "b.txt"])
        let store = PersistenceStore(directory: sandbox.directory.appendingPathComponent("store"))
        var moves = 0
        let model = AppModel(store: store) { from, to in
            moves += 1
            guard moves == 1 else { throw CocoaError(.fileWriteUnknown) }
            try FileManager.default.moveItem(at: from, to: to)
        }
        model.add(urls: sandbox.urls(["a.txt", "b.txt"]))
        model.kind = .prepend
        model.prependText = "x-"

        // Act
        model.performRename(undoManager: nil)

        // Assert: both problems are reported, the table points at where "a"
        // really is, and the failed batch isn't recorded as history.
        #expect(model.renameFailures == ["x-b.txt", "a.txt (left as x-a.txt)"])
        #expect(sandbox.exists("x-a.txt"))
        #expect(model.items.map(\.originalName) == ["x-a.txt", "b.txt"])
        #expect(model.history.isEmpty)
    }
}
