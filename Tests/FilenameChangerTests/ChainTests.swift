import Foundation
import Testing

@testable import RenameApp
@testable import RenameKit

@Suite("Chains: steps run in order, each on the name the last one left")
struct ChainTests {
    private let hidden = RenameOptions(hideExtension: true)

    /// The proposed name for one file under `steps`, with Hide Extensions on.
    private func chained(
        _ name: String, _ steps: [RenameFunction], provider: FakeMetadataProvider = FakeMetadataProvider()
    ) -> String? {
        proposedName(name, steps: steps, options: hidden, provider: provider)
    }

    @Test("each step works on the name the step before it left")
    func stepsRunInOrder() {
        let steps: [RenameFunction] = [.replaceAll(find: "_", with: " "), .changeCase(.title)]
        #expect(chained("my_holiday_photo.jpg", steps) == "My Holiday Photo.jpg")
    }

    @Test("the order of the steps matters")
    func orderMatters() {
        #expect(chained("a.txt", [.prepend(text: "x-"), .changeCase(.upper)]) == "X-A.txt")
        #expect(chained("a.txt", [.changeCase(.upper), .prepend(text: "x-")]) == "x-A.txt")
    }

    @Test("a step with nothing to match passes the name on rather than skipping the row")
    func unmatchedStepPassesThrough() {
        let steps: [RenameFunction] = [.replaceAll(find: "_", with: " "), .append(text: " v2")]
        #expect(chained("report.pdf", steps) == "report v2.pdf")
    }

    @Test("a Smart Name step not yet read holds the whole row back")
    func waitingStepHoldsTheRow() {
        let steps: [RenameFunction] = [
            .smartName(SmartNameConfig(template: "{title}")), .append(text: " v2"),
        ]
        #expect(chained("scan.pdf", steps) == nil)
    }

    @Test("once read, Smart Name's name goes on to the next step")
    func readSmartNameChains() {
        let provider = documentProvider("scan.pdf", DocumentSummary(title: "Electricity Bill"))
        let steps: [RenameFunction] = [
            .smartName(SmartNameConfig(template: "{title}")),
            .cleanUp(CleanUpConfig(replaceSpaces: true, spaceReplacement: "_")),
        ]
        #expect(chained("scan.pdf", steps, provider: provider) == "Electricity_Bill.pdf")
    }

    @Test("with Hide Extensions off, each step sees the extension as it always would")
    func extensionPerStep() {
        // Smart Name keeps the extension; the Replace after it sees the whole name.
        let provider = documentProvider("scan.pdf", DocumentSummary(title: "Bill"))
        let steps: [RenameFunction] = [
            .smartName(SmartNameConfig(template: "{title}")), .replaceAll(find: ".pdf", with: ".PDF"),
        ]
        let result = proposedName(
            "scan.pdf", steps: steps, options: RenameOptions(hideExtension: false), provider: provider)
        #expect(result == "Bill.PDF")
    }

    @Test("a step that empties the name stops the chain, and the row is flagged invalid")
    func emptiedNameIsInvalid() {
        let plan = RenameEngine.plan(
            items: items(["abc.txt"]), steps: [.removeCharacters(.fromEnd(count: 3)), .append(text: "x")],
            options: RenameOptions(hideExtension: true), provider: FakeMetadataProvider())
        #expect(plan.first?.issue == .invalidName)
    }

    @Test("a Sequence step numbers in its own sort order, wherever it sits in the chain")
    func sequenceSortsTheChain() {
        let steps: [RenameFunction] = [
            .changeCase(.upper),
            .sequence(SequenceConfig(placement: .prepend, digits: 1, sort: .alphabetical)),
        ]
        let plan = RenameEngine.plan(
            items: items(["b.txt", "a.txt"]), steps: steps, options: RenameOptions(hideExtension: true),
            provider: FakeMetadataProvider())
        #expect(plan.map(\.proposedName) == ["1A.txt", "2B.txt"])
    }

    @Test("steps after a filing step work on the name, not the folder")
    func laterStepsSkipTheFolder() {
        let provider = documentProvider("scan.pdf", DocumentSummary(title: "Bill", from: "Acme"))
        let filing = RenameFunction.smartName(SmartNameConfig(template: "{from}/{title}"))
        #expect(chained("scan.pdf", [filing, .changeCase(.upper)], provider: provider) == "Acme/BILL.pdf")
        let numbered = RenameFunction.sequence(SequenceConfig(placement: .prepend, digits: 1))
        #expect(chained("scan.pdf", [filing, numbered], provider: provider) == "Acme/1Bill.pdf")
    }

    @Test("a / another step makes after filing is still an invalid name, not a second folder")
    func laterSlashIsInvalid() {
        let provider = documentProvider("scan.pdf", DocumentSummary(title: "Gas-Bill", from: "Acme"))
        let steps: [RenameFunction] = [
            .smartName(SmartNameConfig(template: "{from}/{title}", textCase: nil)),
            .replaceAll(find: "-", with: "/"),
        ]
        let plan = RenameEngine.plan(
            items: items(["scan.pdf"]), steps: steps, options: hidden, provider: provider)
        #expect(plan.first?.issue == .invalidName)
    }

    @Test("each file's metadata is read once, though a date sort and a date stamp both use it")
    func metadataReadOnce() {
        let provider = CountingProvider()
        let steps: [RenameFunction] = [
            .sequence(SequenceConfig(placement: .prepend, sort: .fileDate)),
            .date(DateConfig(source: .fileCreated, placement: .append)),
        ]
        _ = RenameEngine.plan(
            items: items(["a.txt", "b.txt"]), steps: steps, options: hidden, provider: provider)
        #expect(provider.reads == ["a.txt": 1, "b.txt": 1])
    }
}

/// Counts metadata reads per file name, to show the plan reads each once.
private final class CountingProvider: FileMetadataProvider, @unchecked Sendable {
    private(set) var reads: [String: Int] = [:]

    func metadata(for url: URL) -> FileMetadata {
        reads[url.lastPathComponent, default: 0] += 1
        return FileMetadata(creationDate: Date(timeIntervalSince1970: 0))
    }

    func fileExists(at url: URL) -> Bool { false }
}

@MainActor
@Suite("Chains in the app: adding, moving and saving steps")
struct ChainModelTests {
    @Test("adding a step puts it after the one being edited, and edits it")
    func addStepAfterSelected() {
        let model = makeTestModel()
        model.step.kind = .smartName

        model.addStep()

        #expect(model.steps.map(\.kind) == [.smartName, .prepend])
        #expect(model.selectedStepIndex == 1)
    }

    @Test("a chain stops growing at five steps")
    func stepsAreCapped() {
        let model = makeTestModel()

        for _ in 0..<AppModel.maxSteps { model.addStep() }

        #expect(model.steps.count == 5)
        #expect(!model.canAddStep)
    }

    @Test("a step can be moved and removed, but the last one stays")
    func moveAndRemove() {
        let model = makeTestModel()
        model.step.kind = .smartName
        model.addStep()
        model.step.kind = .cleanUp

        model.moveSelectedStep(by: -1)
        #expect(model.steps.map(\.kind) == [.cleanUp, .smartName])
        #expect(model.selectedStepIndex == 0)

        model.removeSelectedStep()
        model.removeSelectedStep()
        #expect(model.steps.map(\.kind) == [.smartName])
    }

    @Test("the plan runs every step")
    func planRunsTheChain() {
        let model = makeTestModel()
        model.add(urls: [URL(fileURLWithPath: "/tmp/fnc-chain/a_b.txt")])
        model.step.kind = .replaceAll
        model.step.findText = "_"
        model.step.replaceText = " "
        model.addStep()
        model.step.kind = .changeCase
        model.step.textCase = .upper

        #expect(model.plan.map(\.proposedName) == ["A B.txt"])
    }

    @Test("a preset saves the whole chain and brings it back")
    func presetKeepsChain() throws {
        let sandbox = try Sandbox()
        let model = makeTestModel(storeIn: sandbox.root)
        model.step.kind = .smartName
        model.step.smartTemplate = "{from} - {title}"
        model.addStep()
        model.step.kind = .cleanUp
        model.saveCurrentAsPreset(named: "Scans")

        let reopened = makeTestModel(storeIn: sandbox.root)
        try reopened.apply(#require(reopened.presets.first))

        #expect(reopened.steps.map(\.kind) == [.smartName, .cleanUp])
        #expect(reopened.steps[0].smartTemplate == "{from} - {title}")
    }

    @Test("a preset saved before chains still loads, as one step")
    func legacyPresetLoads() throws {
        let sandbox = try Sandbox()
        sandbox.file(
            "presets.json",
            contents: """
                [{"name": "Add year", "kind": "prepend",
                  "function": {"prepend": {"text": "2026-"}},
                  "options": {"hideExtension": true, "ignoreCase": false, "forceUnique": false}}]
                """)

        let presets = PersistenceStore(directory: sandbox.root).loadPresets()

        #expect(presets.first?.steps == [.prepend(text: "2026-")])
        #expect(!sandbox.exists("presets.json.bak"))
    }

    @Test("a date-sorted Sequence after Smart Name still sorts by the files' dates")
    func dateSortAfterSmartName() async {
        let provider = FakeMetadataProvider(metadataByName: [
            "a.pdf": FileMetadata(modificationDate: Date(timeIntervalSince1970: 200)),
            "b.pdf": FileMetadata(modificationDate: Date(timeIntervalSince1970: 100)),
        ])
        let model = makeTestModel(
            provider: provider, summarizer: FakeSummarizer(titles: ["a.pdf": "Later", "b.pdf": "Earlier"]))
        model.add(urls: [
            URL(fileURLWithPath: "/tmp/fnc-chain/a.pdf"), URL(fileURLWithPath: "/tmp/fnc-chain/b.pdf"),
        ])
        model.step.kind = .smartName
        model.step.smartTemplate = "{title}"
        model.addStep()
        model.step.kind = .sequence
        model.step.sequence = SequenceConfig(placement: .prepend, digits: 1, sort: .fileDate)
        await model.analysis.waitUntilIdle()

        #expect(model.plan.map(\.proposedName) == ["1Earlier.pdf", "2Later.pdf"])
        #expect(!model.allowsManualOrder)
    }

    @Test("Smart Name in a later step still reads the files")
    func smartNameLaterStepReads() async {
        let summarizer = FakeSummarizer(titles: ["a.pdf": "Water Bill"])
        let model = makeTestModel(summarizer: summarizer)
        model.add(urls: [URL(fileURLWithPath: "/tmp/fnc-chain/a.pdf")])
        model.step.kind = .cleanUp
        model.addStep()
        model.step.kind = .smartName

        await model.analysis.waitUntilIdle()

        #expect(await summarizer.calls == ["a.pdf"])
    }
}
