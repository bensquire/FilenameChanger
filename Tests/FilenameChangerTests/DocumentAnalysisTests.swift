import Foundation
import Testing

@testable import RenameApp
@testable import RenameIntelligence
@testable import RenameKit

@MainActor
@Suite("Smart Name: reading files in the app")
struct DocumentAnalysisTests {
    private func makeModel(_ summarizer: FakeSummarizer, names: [String]) -> AppModel {
        let model = makeTestModel(summarizer: summarizer, moveItem: { _, _ in })
        model.add(urls: names.map { URL(fileURLWithPath: "/tmp/fnc-analysis/\($0)") })
        model.smartTemplate = "{title}"
        return model
    }

    @Test("reading a file gives its row a name")
    func readingFillsThePlan() async {
        let model = makeModel(FakeSummarizer(titles: ["a.pdf": "Water Bill"]), names: ["a.pdf"])
        model.kind = .smartName

        model.analyzeIfNeeded()
        await model.analysis.waitUntilIdle()

        #expect(model.plan.map(\.proposedName) == ["Water Bill.pdf"])
    }

    @Test("a batch is read in order, the next file's text got ahead of the model")
    func batchReadInOrder() async {
        let titles = ["a.pdf": "Water Bill", "b.pdf": "Gas Bill", "c.pdf": "Payslip"]
        let summarizer = FakeSummarizer(titles: titles)
        let model = makeModel(summarizer, names: ["a.pdf", "b.pdf", "c.pdf"])
        model.kind = .smartName

        await model.analysis.waitUntilIdle()

        #expect(await summarizer.calls == ["a.pdf", "b.pdf", "c.pdf"])
        #expect(model.plan.map(\.proposedName) == ["Water Bill.pdf", "Gas Bill.pdf", "Payslip.pdf"])
    }

    @Test("each file is read once, however often reading is asked for")
    func eachFileReadOnce() async {
        let summarizer = FakeSummarizer(titles: ["a.pdf": "Water Bill"])
        let model = makeModel(summarizer, names: ["a.pdf"])
        model.kind = .smartName

        model.analyzeIfNeeded()
        model.analyzeIfNeeded()
        await model.analysis.waitUntilIdle()
        model.analyzeIfNeeded()
        await model.analysis.waitUntilIdle()

        #expect(await summarizer.calls == ["a.pdf"])
    }

    @Test("a renamed file keeps what was read, so it isn't read again")
    func summarySurvivesRename() async {
        let summarizer = FakeSummarizer(titles: ["a.pdf": "Water Bill"])
        let model = makeModel(summarizer, names: ["a.pdf"])
        model.kind = .smartName
        model.analyzeIfNeeded()
        await model.analysis.waitUntilIdle()

        model.performRename(undoManager: nil)
        model.analyzeIfNeeded()
        await model.analysis.waitUntilIdle()

        #expect(model.items.map(\.originalName) == ["Water Bill.pdf"])
        #expect(model.analysis.summaries.count == 1)
        #expect(await summarizer.calls == ["a.pdf"])
    }

    @Test("a file that can't be read says why, and isn't renamed")
    func failureIsReported() async {
        let model = makeModel(FakeSummarizer(titles: [:]), names: ["a.zip"])
        model.kind = .smartName

        model.analyzeIfNeeded()
        await model.analysis.waitUntilIdle()

        let id = model.items[0].id
        #expect(model.analysis.status[id] == .failed(DocumentText.Failure.noText.localizedDescription))
        #expect(RenameEngine.actionableRenames(model.plan).isEmpty)
    }

    @Test("removing a file forgets what was read")
    func removeForgets() async {
        let model = makeModel(FakeSummarizer(titles: ["a.pdf": "Water Bill"]), names: ["a.pdf"])
        model.kind = .smartName
        model.analyzeIfNeeded()
        await model.analysis.waitUntilIdle()

        model.remove(ids: [model.items[0].id])

        #expect(model.analysis.summaries.isEmpty)
    }

    @Test("nothing is read unless Smart Name is the chosen function")
    func readsOnlyForSmartName() async {
        let summarizer = FakeSummarizer(titles: ["a.pdf": "Water Bill"])
        let model = makeModel(summarizer, names: ["a.pdf"])
        model.kind = .date

        model.analyzeIfNeeded()
        await model.analysis.waitUntilIdle()

        #expect(await summarizer.calls.isEmpty)
    }

    @Test("nothing is read while Apple Intelligence is unavailable")
    func readsOnlyWhenAvailable() async {
        let summarizer = FakeSummarizer(titles: ["a.pdf": "Water Bill"], availability: .appleIntelligenceOff)
        let model = makeModel(summarizer, names: ["a.pdf"])
        model.kind = .smartName

        model.analyzeIfNeeded()
        await model.analysis.waitUntilIdle()

        #expect(await summarizer.calls.isEmpty)
    }

    @Test("a document's date reads as that day wherever the Mac is")
    func modelDateParsing() {
        let date = AppleIntelligenceSummarizer.date(from: "2026-03-03")
        // Formatted through the stamp a name gets.
        #expect(date.map { DateStamp.string(from: $0, pattern: "yyyyMMdd") } == "20260303")
        #expect(AppleIntelligenceSummarizer.date(from: "") == nil)
        #expect(AppleIntelligenceSummarizer.date(from: "2026-02-30") == nil)
        #expect(AppleIntelligenceSummarizer.date(from: "0026-03-03") == nil)
    }
}
