import Foundation
import Testing

@testable import RenameApp
@testable import RenameKit

@MainActor
@Suite("AppModel: reordering")
struct ModelTests {
    private func makeModel(_ names: [String]) -> AppModel {
        let model = makeTestModel()
        model.add(urls: names.map { URL(fileURLWithPath: "/tmp/\($0)") })
        return model
    }

    @Test("the app protects extensions by default (Hide Extensions on)")
    func defaultProtectsExtensions() {
        #expect(makeModel(["a"]).options.hideExtension)
    }

    @Test("the same file is queued once, however it arrives")
    func addQueuesEachFileOnce() {
        // Arrange: one file named four ways — twice in one batch, through the
        // /tmp → /private/tmp symlink, and with a redundant "x/..".
        let model = makeModel([])
        let name = "dup-\(UUID().uuidString).txt"
        let file = URL(fileURLWithPath: "/tmp/\(name)")

        // Act
        model.add(urls: [
            file, file,
            URL(fileURLWithPath: "/private/tmp/\(name)"),
            URL(fileURLWithPath: "/tmp/x/../\(name)"),
        ])
        model.add(urls: [file])  // and again in a later add

        // Assert
        #expect(model.items.count == 1)
    }

    @Test("dragging a row to an offset reorders the files")
    func moveRowsReorders() {
        // Arrange
        let model = makeModel(["a", "b", "c"])
        let cID = model.items[2].id.uuidString
        // Act: move "c" to the front.
        model.moveRows(ids: [cID], toOffset: 0)
        // Assert
        #expect(model.items.map(\.originalName) == ["c", "a", "b"])
    }

}
