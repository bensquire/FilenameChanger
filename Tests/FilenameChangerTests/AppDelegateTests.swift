import AppKit
import Foundation
import Testing

@testable import RenameApp

/// Files arriving from Finder: Open With (and a Dock drop), which AppKit hands
/// to `application(_:open:)`, and the "Rename with FilenameChanger" Service.
@MainActor
@Suite("AppDelegate: files from Finder")
struct AppDelegateTests {
    /// A throwaway folder of empty files, removed on deinit.
    private func makeDelegate(in sandbox: Sandbox) -> AppDelegate {
        AppDelegate(model: makeTestModel(storeIn: sandbox.url("store")))
    }

    @Test("Open With adds the files, and a folder's files")
    func openWithAddsFiles() throws {
        // Arrange
        let sandbox = try Sandbox(["notes.txt", "photos/a.jpg", "photos/b.jpg"])
        let delegate = makeDelegate(in: sandbox)

        // Act
        delegate.application(
            NSApplication.shared,
            open: [
                sandbox.root.appending(component: "notes.txt"), sandbox.root.appending(component: "photos"),
            ])

        // Assert
        let names = delegate.model.items.map(\.originalName).sorted()
        #expect(names == ["a.jpg", "b.jpg", "notes.txt"])
    }

    @Test("the Service adds file URLs and ignores a web link")
    func serviceTakesFileURLsOnly() throws {
        // Arrange: a pasteboard carrying one file and one web page.
        let sandbox = try Sandbox(["notes.txt"])
        let delegate = makeDelegate(in: sandbox)
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        let file = sandbox.root.appending(component: "notes.txt")
        let web = try #require(URL(string: "https://example.com/page.html"))
        pasteboard.writeObjects([file as NSURL, web as NSURL])
        var error: NSString = ""

        // Act
        delegate.renameFiles(pasteboard, userData: nil, error: &error)

        // Assert
        #expect(delegate.model.items.map(\.originalName) == ["notes.txt"])
        #expect(error == "")
    }

    @Test("the Service reports a pasteboard with no files")
    func serviceReportsNoFiles() throws {
        let sandbox = try Sandbox([])
        let delegate = makeDelegate(in: sandbox)
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        var error: NSString = ""

        delegate.renameFiles(pasteboard, userData: nil, error: &error)

        #expect(delegate.model.items.isEmpty)
        #expect(error == "FilenameChanger was sent no files.")
    }
}
