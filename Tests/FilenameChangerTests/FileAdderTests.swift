import Foundation
import Testing

@testable import RenameApp

/// `FileAdder.expandForDrop` — the no-panel path used by drag-and-drop and the
/// Finder Service. Exercises it against real temp files so the folder walk and
/// package handling are covered.
@MainActor
@Suite("FileAdder: expanding dropped folders and packages")
struct FileAdderTests {
    /// A throwaway directory tree, removed on deinit.
    private final class Sandbox {
        let root: URL
        init() throws {
            root = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("fnc-adder-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        }
        @discardableResult func file(_ path: String) -> URL {
            let url = root.appendingPathComponent(path)
            try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: url.path, contents: Data())
            return url
        }
        @discardableResult func directory(_ path: String) -> URL {
            let url = root.appendingPathComponent(path)
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }
        deinit { try? FileManager.default.removeItem(at: root) }
    }

    @Test("a dropped folder expands to its files, recursively")
    func expandsFolderRecursively() throws {
        let sandbox = try Sandbox()
        sandbox.file("photos/a.jpg")
        sandbox.file("photos/b.jpg")
        sandbox.file("photos/sub/c.jpg")
        let folder = sandbox.root.appendingPathComponent("photos")

        let result = FileAdder.expandForDrop([folder]).map(\.lastPathComponent).sorted()

        #expect(result == ["a.jpg", "b.jpg", "c.jpg"])
    }

    @Test("a plain file passes through unchanged")
    func passesFilesThrough() throws {
        let sandbox = try Sandbox()
        let file = sandbox.file("notes.txt")

        #expect(FileAdder.expandForDrop([file]) == [file])
    }

    @Test("a package is added as one item, not opened up")
    func keepsPackagesWhole() throws {
        let sandbox = try Sandbox()
        let app = sandbox.directory("Thing.app")
        sandbox.file("Thing.app/Contents/Info.plist")

        // ".app" is a package: it should come back whole, not as its innards.
        #expect(FileAdder.expandForDrop([app]) == [app])
    }

    @Test("hidden files such as .DS_Store are never queued")
    func skipsHiddenFiles() throws {
        let sandbox = try Sandbox()
        sandbox.file("photos/a.jpg")
        sandbox.file("photos/.DS_Store")
        sandbox.file("photos/.cache/b.jpg")  // a hidden folder isn't walked either
        let folder = sandbox.root.appendingPathComponent("photos")

        let result = FileAdder.expandForDrop([folder]).map(\.lastPathComponent)

        #expect(result == ["a.jpg"])
    }
}
