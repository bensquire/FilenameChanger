import AppIntents
import Foundation
import Testing

@testable import RenameApp
@testable import RenameKit

@MainActor
@Suite("Shortcuts: renaming without the window")
struct ShortcutsTests {
    private func makeModel(in sandbox: Sandbox, _ summarizer: FakeSummarizer = FakeSummarizer(titles: [:]))
        -> AppModel
    {
        makeTestModel(
            provider: SystemFileMetadataProvider(), summarizer: summarizer, storeIn: sandbox.url("store"))
    }

    @Test("a chain renames the files on disk and is kept in history")
    func renamesWithSteps() async throws {
        let sandbox = try Sandbox(["a_b.txt", "c.txt"])
        let model = makeModel(in: sandbox)

        let outcome = try await model.rename(
            sandbox.urls(["a_b.txt", "c.txt"]),
            steps: [.replaceAll(find: "_", with: " "), .changeCase(.upper)],
            options: RenameOptions(hideExtension: true))

        #expect(sandbox.exists("A B.txt") && sandbox.exists("C.txt"))
        #expect(outcome.files.map(\.lastPathComponent) == ["A B.txt", "C.txt"])
        #expect(model.history.first?.rows.count == 2)
    }

    @Test("the window's own files and steps are left as they were")
    func windowUntouched() async throws {
        let sandbox = try Sandbox(["a.txt", "b.txt"])
        let model = makeModel(in: sandbox)
        model.add(urls: [sandbox.url("b.txt")])
        model.step.kind = .changeCase

        _ = try await model.rename(
            [sandbox.url("a.txt")], steps: [.prepend(text: "x-")], options: RenameOptions())

        #expect(model.items.map(\.originalName) == ["b.txt"])
        #expect(model.steps.map(\.kind) == [.changeCase])
    }

    @Test("a file also in the window follows its rename there")
    func windowRowFollows() async throws {
        let sandbox = try Sandbox(["a.txt"])
        let model = makeModel(in: sandbox)
        model.add(urls: [sandbox.url("a.txt")])

        _ = try await model.rename(
            [sandbox.url("a.txt")], steps: [.prepend(text: "x-")], options: RenameOptions())

        #expect(model.items.map(\.originalName) == ["x-a.txt"])
    }

    @Test("Smart Name reads each file, and one it can't read is left as it is, with the reason")
    func smartNameReadsAndSkips() async throws {
        let sandbox = try Sandbox(["scan.pdf", "archive.zip"])
        let model = makeModel(in: sandbox, FakeSummarizer(titles: ["scan.pdf": "Water Bill"]))

        let outcome = try await model.rename(
            sandbox.urls(["scan.pdf", "archive.zip"]),
            steps: [.smartName(SmartNameConfig(template: "{title}"))],
            options: RenameOptions(hideExtension: true))

        #expect(sandbox.exists("Water Bill.pdf") && sandbox.exists("archive.zip"))
        #expect(outcome.skipped.count == 1)
        #expect(outcome.skipped.first?.hasPrefix("archive.zip: ") == true)
    }

    @Test("Smart Name says why when Apple Intelligence can't run, and renames nothing")
    func smartNameUnavailable() async throws {
        let sandbox = try Sandbox(["scan.pdf"])
        let model = makeModel(
            in: sandbox,
            FakeSummarizer(titles: ["scan.pdf": "Water Bill"], availability: .appleIntelligenceOff))

        await #expect(throws: OutsideRenameError.self) {
            try await model.rename(
                [sandbox.url("scan.pdf")], steps: [.smartName(SmartNameConfig())],
                options: RenameOptions(hideExtension: true))
        }
        #expect(sandbox.exists("scan.pdf"))
    }

    @Test("a name that would collide is skipped with the reason, the rest renamed")
    func collisionSkipped() async throws {
        let sandbox = try Sandbox(["a.txt", "x-a.txt", "b.txt"])
        let model = makeModel(in: sandbox)

        let outcome = try await model.rename(
            sandbox.urls(["a.txt", "b.txt"]), steps: [.prepend(text: "x-")], options: RenameOptions())

        #expect(outcome.skipped == ["a.txt: \(RenameIssue.collision.explanation)"])
        #expect(outcome.files.map(\.lastPathComponent) == ["a.txt", "x-b.txt"])
    }

    @Test("when nothing can be renamed, it says why rather than succeeding quietly")
    func nothingRenamedThrows() async throws {
        let sandbox = try Sandbox(["archive.zip"])
        let model = makeModel(in: sandbox)

        await #expect(throws: OutsideRenameError.self) {
            try await model.rename(
                [sandbox.url("archive.zip")], steps: [.smartName(SmartNameConfig())],
                options: RenameOptions(hideExtension: true))
        }
        #expect(model.history.isEmpty)
    }

    @Test("a file the window has already read is named from that, not read again")
    func windowReadReused() async throws {
        let sandbox = try Sandbox(["scan.pdf"])
        let summarizer = FakeSummarizer(titles: ["scan.pdf": "Water Bill"])
        let model = makeModel(in: sandbox, summarizer)
        model.add(urls: [sandbox.url("scan.pdf")])
        model.step.kind = .smartName
        await model.analysis.waitUntilIdle()

        _ = try await model.rename(
            [sandbox.url("scan.pdf")], steps: [.smartName(SmartNameConfig(template: "{title}"))],
            options: RenameOptions(hideExtension: true))

        #expect(sandbox.exists("Water Bill.pdf"))
        #expect(await summarizer.calls == ["scan.pdf"])
    }

    @Test("a Finder file handed over as /.nofollow/… is renamed at its real path")
    func noFollowPrefixRemoved() {
        let file = IntentFile(fileURL: URL(filePath: "/.nofollow/Users/someone/Desktop/scan.pdf"))
        #expect(file.originalFileURL?.path(percentEncoded: false) == "/Users/someone/Desktop/scan.pdf")
        let plain = IntentFile(fileURL: URL(filePath: "/Users/someone/scan.pdf"))
        #expect(plain.originalFileURL?.path(percentEncoded: false) == "/Users/someone/scan.pdf")
    }
}
