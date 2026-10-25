import Foundation
import Testing

@testable import RenameApp

/// `FileAdder.expandForDrop` — the no-panel path used by drag-and-drop and the
/// Finder Service. Exercises it against real temp files so the folder walk and
/// package handling are covered.
@MainActor
@Suite("FileAdder: expanding dropped folders and packages")
struct FileAdderTests {
    @Test("a dropped folder expands to its files, recursively")
    func expandsFolderRecursively() throws {
        let sandbox = try Sandbox()
        sandbox.file("photos/a.jpg")
        sandbox.file("photos/b.jpg")
        sandbox.file("photos/sub/c.jpg")
        let folder = sandbox.url("photos")

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
        let folder = sandbox.url("photos")

        let result = FileAdder.expandForDrop([folder]).map(\.lastPathComponent)

        #expect(result == ["a.jpg"])
    }
}
