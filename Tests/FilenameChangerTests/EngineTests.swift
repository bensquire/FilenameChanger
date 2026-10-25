import Foundation
import Testing

@testable import RenameKit

@Suite("Engine: skipping, extensions, collisions, force unique")
struct EngineTests {
    @Test("an unchecked row is left untouched")
    func disabledRowSkipped() {
        // Arrange
        var file = items(["photo.jpg"])[0]
        file.isEnabled = false
        // Act
        let plan = RenameEngine.plan(
            items: [file], function: .prepend(text: "x-"), options: RenameOptions(),
            provider: FakeMetadataProvider())
        // Assert
        #expect(plan.first?.willRename == false)
        #expect(plan.first?.proposedName == "photo.jpg")
    }

    @Test("a function that produces the same name does not rename")
    func unchangedNameSkips() {
        let plan = RenameEngine.plan(
            items: items(["photo.jpg"]), function: .prepend(text: ""), options: RenameOptions(),
            provider: FakeMetadataProvider())
        #expect(plan.first?.willRename == false)
    }

    @Test("two rows resolving to one name are both flagged as duplicates")
    func duplicateResultsFlagged() {
        // Arrange: a regex that maps every base to the literal "same".
        let function = RenameFunction.regex(pattern: ".+", template: "same")
        // Act
        let plan = RenameEngine.plan(
            items: items(["a.txt", "b.txt"]), function: function,
            options: RenameOptions(hideExtension: true), provider: FakeMetadataProvider())
        // Assert
        #expect(plan.allSatisfy { $0.issue == .duplicateResult })
        #expect(plan.allSatisfy { !$0.willRename })
    }

    @Test("Force Unique bumps the colliding name with a counter")
    func forceUniqueBumps() {
        let function = RenameFunction.regex(pattern: ".+", template: "same")
        let plan = RenameEngine.plan(
            items: items(["a.txt", "b.txt"]), function: function,
            options: RenameOptions(hideExtension: true, forceUnique: true),
            provider: FakeMetadataProvider())
        #expect(plan.map(\.proposedName) == ["same.txt", "same 1.txt"])
        #expect(plan.allSatisfy { $0.issue == nil && $0.willRename })
    }

    @Test("a name already on disk outside the batch is flagged as a collision")
    func diskCollisionFlagged() {
        // Arrange: the target "report.txt" already exists on disk.
        let provider = FakeMetadataProvider(existingNames: ["report.txt"])
        // Act
        let plan = RenameEngine.plan(
            items: items(["draft.txt"]), function: .replaceFirst(find: "draft", with: "report"),
            options: RenameOptions(), provider: provider)
        // Assert
        #expect(plan.first?.issue == .collision)
        #expect(plan.first?.willRename == false)
    }

    @Test("Force Unique steps past a name that already exists on disk")
    func forceUniquePastDisk() {
        let provider = FakeMetadataProvider(existingNames: ["report.txt"])
        let plan = RenameEngine.plan(
            items: items(["draft.txt"]), function: .replaceFirst(find: "draft", with: "report"),
            options: RenameOptions(forceUnique: true), provider: provider)
        #expect(plan.first?.proposedName == "report 1.txt")
        #expect(plan.first?.willRename == true)
    }

    @Test("a case-only rename is not a false collision with itself")
    func caseOnlyRenameNotCollision() {
        // A case-insensitive file system reports the new-case name as existing,
        // because it is the same file — this must not block the rename.
        let provider = FakeMetadataProvider(existingNames: ["photo.jpg"])
        let plan = RenameEngine.plan(
            items: items(["PHOTO.JPG"]), function: .changeCase(.lower),
            options: RenameOptions(), provider: provider)
        #expect(plan.first?.proposedName == "photo.jpg")
        #expect(plan.first?.issue == nil)
        #expect(plan.first?.willRename == true)
    }

    @Test("a result that is empty is flagged as an invalid name")
    func emptyNameInvalid() {
        // "ab" with no extension, remove 2 from the end → "".
        let plan = RenameEngine.plan(
            items: items(["ab"]), function: .removeCharacters(.fromEnd(count: 2)),
            options: RenameOptions(), provider: FakeMetadataProvider())
        #expect(plan.first?.issue == .invalidName)
        #expect(plan.first?.willRename == false)
    }

    @Test("Hide Extensions strips the extension from the displayed name only")
    func displayNameHidesExtension() {
        // Off: the name is shown whole.
        #expect(RenameOptions(hideExtension: false).displayName(for: "photo.jpg") == "photo.jpg")
        // On: only the extension is hidden for display.
        #expect(RenameOptions(hideExtension: true).displayName(for: "photo.jpg") == "photo")
        // A name with no extension is unchanged either way.
        #expect(RenameOptions(hideExtension: true).displayName(for: "notes") == "notes")
    }

    @Test("two targets differing only in case are flagged as duplicates")
    func caseOnlyDuplicatesFlagged() {
        // On a case-insensitive volume "Same.txt" and "same.txt" are one file,
        // so both rows must be blocked rather than one silently clobbering.
        let plan = RenameEngine.plan(
            items: items(["Same-1.txt", "same-2.txt"]),
            function: .regex(pattern: #"-\d+"#, template: ""),
            options: RenameOptions(), provider: FakeMetadataProvider())
        #expect(plan.map(\.proposedName) == ["Same.txt", "same.txt"])
        #expect(plan.allSatisfy { $0.issue == .duplicateResult && !$0.willRename })
    }

    @Test("Force Unique bumps a target that differs from another only in case")
    func forceUniqueCaseOnly() {
        let plan = RenameEngine.plan(
            items: items(["Same-1.txt", "same-2.txt"]),
            function: .regex(pattern: #"-\d+"#, template: ""),
            options: RenameOptions(forceUnique: true), provider: FakeMetadataProvider())
        #expect(plan.map(\.proposedName) == ["Same.txt", "same 1.txt"])
        #expect(plan.allSatisfy { $0.issue == nil && $0.willRename })
    }

    @Test("two files in different folders may take the same name")
    func crossDirectorySameNameAllowed() {
        let plan = RenameEngine.plan(
            items: items(["x.txt"], in: URL(fileURLWithPath: "/tmp/fnc-a"))
                + items(["y.txt"], in: URL(fileURLWithPath: "/tmp/fnc-b")),
            function: .regex(pattern: ".+", template: "out.txt"),
            options: RenameOptions(), provider: FakeMetadataProvider())
        #expect(plan.allSatisfy { $0.proposedName == "out.txt" })
        #expect(plan.allSatisfy { $0.issue == nil && $0.willRename })
    }

    @Test("a result of \".\" or \"..\" is an invalid name")
    func dotNamesInvalid() {
        let plan = RenameEngine.plan(
            items: items(["x"]), function: .replaceAll(find: "x", with: "."),
            options: RenameOptions(), provider: FakeMetadataProvider())
        #expect(plan.first?.issue == .invalidName)
    }

    @Test("planOverride validates and flags collisions through the provider")
    func planOverrideRules() {
        let item = items(["draft.txt"])[0]
        let provider = FakeMetadataProvider(existingNames: ["taken.txt"])
        // A clean new name renames.
        #expect(
            RenameEngine.planOverride(name: "final.txt", for: item, provider: provider).willRename)
        // A name already on disk is a collision (seen via the injected provider).
        #expect(
            RenameEngine.planOverride(name: "taken.txt", for: item, provider: provider).issue
                == .collision)
        // An empty name is invalid; the unchanged name is a no-op.
        #expect(
            RenameEngine.planOverride(name: "", for: item, provider: provider).issue == .invalidName)
        #expect(
            !RenameEngine.planOverride(name: "draft.txt", for: item, provider: provider).willRename)
    }

    @Test("a shift onto names the batch vacates is allowed, not flagged")
    func shiftChainAllRename() {
        // 1,2,3 all exist on disk; renumber to 2,3,4. Each target but the last
        // is occupied by a file that the batch itself moves, so none collide.
        let provider = FakeMetadataProvider(existingNames: ["1.txt", "2.txt", "3.txt"])
        let config = SequenceConfig(placement: .replaceAll, digits: 1, start: 2, sort: .custom)
        let plan = RenameEngine.plan(
            items: items(["1.txt", "2.txt", "3.txt"]), function: .sequence(config),
            options: RenameOptions(hideExtension: true), provider: provider)
        #expect(plan.map(\.proposedName) == ["2.txt", "3.txt", "4.txt"])
        #expect(plan.allSatisfy { $0.issue == nil && $0.willRename })
    }

    @Test("a swap cycle is allowed, not flagged as a mutual collision")
    func swapCycleAllRename() {
        // Table order 2,1 renumbered from 1 swaps the two names; both exist on
        // disk, but each is the other's source, so both rename.
        let provider = FakeMetadataProvider(existingNames: ["1.txt", "2.txt"])
        let config = SequenceConfig(placement: .replaceAll, digits: 1, start: 1, sort: .custom)
        let plan = RenameEngine.plan(
            items: items(["2.txt", "1.txt"]), function: .sequence(config),
            options: RenameOptions(hideExtension: true), provider: provider)
        #expect(plan.map(\.proposedName) == ["1.txt", "2.txt"])
        #expect(plan.allSatisfy { $0.issue == nil && $0.willRename })
    }

    @Test("a shift across packages sees the names the batch vacates")
    func packageShiftAllRename() {
        // Arrange: packages as a folder walk finds them, with a trailing "/".
        // A target built from a name has none, yet names the same path.
        let folder = URL(filePath: "/tmp/fnc-test/", directoryHint: .isDirectory)
        let packages = ["1.app", "2.app"].map {
            FileItem(url: folder.appending(component: $0, directoryHint: .isDirectory))
        }
        let provider = FakeMetadataProvider(existingNames: ["1.app", "2.app"])
        let config = SequenceConfig(placement: .replaceAll, digits: 1, start: 2, sort: .custom)

        // Act
        let plan = RenameEngine.plan(
            items: packages, function: .sequence(config),
            options: RenameOptions(hideExtension: true), provider: provider)

        // Assert: 1 → 2 is allowed because 2 moves out to 3.
        #expect(plan.map(\.proposedName) == ["2.app", "3.app"])
        #expect(plan.allSatisfy { $0.issue == nil && $0.willRename })
    }

    @Test("a target held by a file that stays put is still a collision")
    func collisionWhenOccupantStaysPut() {
        // "b.txt" is in the list but unchanged (it does not move), so renaming
        // a.txt → b.txt must still be blocked.
        let provider = FakeMetadataProvider(existingNames: ["b.txt"])
        let plan = RenameEngine.plan(
            items: items(["a.txt", "b.txt"]), function: .replaceAll(find: "a", with: "b"),
            options: RenameOptions(hideExtension: true), provider: provider)
        #expect(plan.first?.proposedName == "b.txt")
        #expect(plan.first?.issue == .collision)
        #expect(plan.first?.willRename == false)
    }

    @Test("actionableRenames keeps only the rows that will change cleanly")
    func actionableFilter() {
        let provider = FakeMetadataProvider(existingNames: ["taken.txt"])
        let plan = RenameEngine.plan(
            items: items(["a.txt", "taken-src.txt"]),
            function: .replaceFirst(find: "a.txt", with: "b.txt"),
            options: RenameOptions(), provider: provider)
        let actionable = RenameEngine.actionableRenames(plan)
        #expect(actionable.count == 1)
        #expect(actionable.first?.proposedName == "b.txt")
    }

    @Test(
        "a function that empties the name is flagged invalid, never a hidden \".ext\"",
        arguments: [
            RenameFunction.removeCharacters(.fromEnd(count: 5)),
            .removeCharacters(.range(location: 0, length: 99)),
            .replaceAll(find: "ab", with: ""),
            .regex(pattern: ".*", template: ""),
        ])
    func emptiedNameIsInvalid(function: RenameFunction) {
        // With Hide Extensions on, an emptied base would rejoin as ".jpg".
        let plan = RenameEngine.plan(
            items: items(["ab.jpg"]), function: function,
            options: RenameOptions(hideExtension: true), provider: FakeMetadataProvider())
        #expect(plan.first?.issue == .invalidName)
        #expect(plan.first?.willRename == false)
    }

    @Test("a name left as only spaces is flagged invalid")
    func blankNameIsInvalid() {
        let plan = RenameEngine.plan(
            items: items(["ab.jpg"]), function: .replaceAll(find: "ab", with: "  "),
            options: RenameOptions(hideExtension: true), provider: FakeMetadataProvider())
        #expect(plan.first?.issue == .invalidName)
    }

    @Test("metadata is read only for a Date stamp that uses it")
    func metadataReadOnlyWhenUsed() {
        let files = items(["a.jpg", "b.jpg"])
        let provider = CountingProvider()

        _ = RenameEngine.plan(
            items: files, function: .prepend(text: "x"), options: RenameOptions(),
            provider: provider)
        _ = RenameEngine.plan(
            items: files, function: .date(DateConfig(source: .custom(Date()))),
            options: RenameOptions(), provider: provider)
        #expect(provider.calls == 0)

        _ = RenameEngine.plan(
            items: files, function: .date(DateConfig(source: .fileCreated)),
            options: RenameOptions(), provider: provider)
        #expect(provider.calls == 2)
    }
}

/// Counts metadata reads. The engine calls it synchronously on the test's own
/// thread, so the unsynchronised counter is safe here.
private final class CountingProvider: FileMetadataProvider, @unchecked Sendable {
    var calls = 0

    func metadata(for url: URL) -> FileMetadata {
        calls += 1
        return FileMetadata()
    }

    func fileExists(at url: URL) -> Bool { false }
}
