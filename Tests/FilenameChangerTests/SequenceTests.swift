import Foundation
import Testing

@testable import RenameKit

@Suite("Sequence renaming: numbering, digits, placement, sort")
struct SequenceTests {
    private let hidden = RenameOptions(hideExtension: true)

    @Test("replace-all numbers files in their given order")
    func numbersInOrder() {
        // Arrange
        let config = SequenceConfig(
            name: "img-", namePosition: .before, placement: .replaceAll,
            digits: 3, start: 1, sort: .custom)
        // Act
        let plan = RenameEngine.plan(
            items: items(["c.jpg", "a.jpg", "b.jpg"]), function: .sequence(config),
            options: hidden, provider: FakeMetadataProvider())
        // Assert: order preserved, zero-padded to three digits.
        #expect(plan.map(\.proposedName) == ["img-001.jpg", "img-002.jpg", "img-003.jpg"])
    }

    @Test("replace-all keeps the extension only when Hide Extensions is on")
    func replaceAllAndExtensions() {
        let config = SequenceConfig(name: "", placement: .replaceAll, digits: 3, sort: .custom)
        // On (the app's default): the number replaces the name, extension kept.
        #expect(
            RenameEngine.plan(
                items: items(["photo.jpg"]), function: .sequence(config),
                options: hidden, provider: FakeMetadataProvider()
            ).first?.proposedName == "001.jpg")
        // Off: "Replace all" replaces the whole name, extension included.
        #expect(
            RenameEngine.plan(
                items: items(["photo.jpg"]), function: .sequence(config),
                options: RenameOptions(), provider: FakeMetadataProvider()
            ).first?.proposedName == "001")
    }

    @Test("a disabled row leaves no gap in the numbering")
    func disabledRowNoGap() {
        var files = items(["a.jpg", "b.jpg", "c.jpg"])
        files[1].isEnabled = false  // skip the middle one
        let config = SequenceConfig(name: "", placement: .replaceAll, digits: 3, sort: .custom)
        let plan = RenameEngine.plan(
            items: files, function: .sequence(config), options: hidden,
            provider: FakeMetadataProvider())
        // a and c number contiguously; the disabled row burns no index.
        #expect(plan.filter(\.willRename).map(\.proposedName) == ["001.jpg", "002.jpg"])
    }

    @Test("the start value sets the first index")
    func honoursStart() {
        let config = SequenceConfig(
            name: "", placement: .replaceAll, digits: 2, start: 7, sort: .custom)
        let plan = RenameEngine.plan(
            items: items(["a.jpg", "b.jpg"]), function: .sequence(config),
            options: hidden, provider: FakeMetadataProvider())
        #expect(plan.map(\.proposedName) == ["07.jpg", "08.jpg"])
    }

    @Test("the name can sit after the index digits")
    func namePositionAfter() {
        let config = SequenceConfig(
            name: "-shot", namePosition: .after, placement: .replaceAll,
            digits: 3, start: 1, sort: .custom)
        let plan = RenameEngine.plan(
            items: items(["x.jpg"]), function: .sequence(config),
            options: hidden, provider: FakeMetadataProvider())
        #expect(plan.first?.proposedName == "001-shot.jpg")
    }

    @Test("append keeps the original name and adds the sequence")
    func placementAppend() {
        let config = SequenceConfig(
            name: "_", namePosition: .before, placement: .append,
            digits: 2, start: 1, sort: .custom)
        let plan = RenameEngine.plan(
            items: items(["holiday.jpg"]), function: .sequence(config),
            options: hidden, provider: FakeMetadataProvider())
        #expect(plan.first?.proposedName == "holiday_01.jpg")
    }

    @Test("alphabetical sort numbers by name regardless of input order")
    func sortAlphabetical() {
        let config = SequenceConfig(
            name: "", placement: .replaceAll, digits: 2, start: 1,
            sort: .alphabetical, ascending: true)
        let plan = RenameEngine.plan(
            items: items(["c.jpg", "a.jpg", "b.jpg"]), function: .sequence(config),
            options: hidden, provider: FakeMetadataProvider())
        // Rows come back in sorted (working) order: a, b, c → 01, 02, 03.
        #expect(plan.map(\.originalName) == ["a.jpg", "b.jpg", "c.jpg"])
        #expect(plan.map(\.proposedName) == ["01.jpg", "02.jpg", "03.jpg"])
    }

    @Test("file-date sort numbers oldest-first when ascending")
    func sortFileDateAscending() {
        // Arrange: b is older than a, so ascending puts b first.
        let provider = FakeMetadataProvider(metadataByName: [
            "a.jpg": FileMetadata(modificationDate: Date(timeIntervalSince1970: 2000)),
            "b.jpg": FileMetadata(modificationDate: Date(timeIntervalSince1970: 1000)),
        ])
        let config = SequenceConfig(
            name: "", placement: .replaceAll, digits: 1, start: 1,
            sort: .fileDate, ascending: true)
        // Act
        let plan = RenameEngine.plan(
            items: items(["a.jpg", "b.jpg"]), function: .sequence(config),
            options: hidden, provider: provider)
        // Assert
        #expect(plan.map(\.originalName) == ["b.jpg", "a.jpg"])
        #expect(plan.map(\.proposedName) == ["1.jpg", "2.jpg"])
    }
}
