import Foundation
import Testing

@testable import RenameApp
@testable import RenameIntelligence
@testable import RenameKit

@Suite("Smart Name: {type}, and filing into folders")
struct SmartFilingTests {
    private let bill = DocumentSummary(
        title: "Electricity Bill", from: "Acme Energy", type: "Bill", date: localNoon(2026, 3, 3))

    private func smartName(_ template: String) -> RenameFunction {
        .smartName(SmartNameConfig(template: template))
    }

    @Test("{type} names what kind of document it is")
    func typeToken() {
        let result = proposedName(
            "scan.pdf", smartName("{type} - {title}"), provider: documentProvider("scan.pdf", bill))
        #expect(result == "Bill - Electricity Bill.pdf")
    }

    @Test("a document of no listed type drops {type} and its separator")
    func missingTypeDrops() {
        var letter = bill
        letter.type = nil
        let result = proposedName(
            "scan.pdf", smartName("{type} - {title}"), provider: documentProvider("scan.pdf", letter))
        #expect(result == "Electricity Bill.pdf")
    }

    @Test("a / in the template files the document into a folder")
    func slashMakesFolder() {
        let result = proposedName(
            "scan.pdf", smartName("{from}/{date} - {title}"), provider: documentProvider("scan.pdf", bill))
        #expect(result == "Acme Energy/20260303 - Electricity Bill.pdf")
    }

    @Test("with no sender, {from}/ files nowhere rather than into a nameless folder")
    func emptyFolderTokenStaysPut() {
        var unsigned = bill
        unsigned.from = nil
        let result = proposedName(
            "scan.pdf", smartName("{from}/{title}"), provider: documentProvider("scan.pdf", unsigned))
        #expect(result == "Electricity Bill.pdf")
    }

    @Test("a / from the document itself never makes a folder")
    func slashInValueIsNotAFolder() {
        var report = bill
        report.title = "Q1/Q2 Report"
        let result = proposedName(
            "scan.pdf", smartName("{title}"), provider: documentProvider("scan.pdf", report))
        #expect(result == "Q1-Q2 Report.pdf")
    }

    @Test(
        "a folder path that can't be made is flagged invalid",
        arguments: ["/{title}", "{title}//{date}", "../{title}", ".hidden/{title}"])
    func badFolderInvalid(template: String) {
        let plan = RenameEngine.plan(
            items: items(["scan.pdf"]), function: smartName(template),
            options: RenameOptions(hideExtension: true),
            provider: documentProvider("scan.pdf", bill))
        #expect(plan.first?.issue == .invalidName)
    }

    @Test("a / from any other function is still an invalid name")
    func otherFunctionsMakeNoFolders() {
        let plan = RenameEngine.plan(
            items: items(["a-b.txt"]), function: .replaceAll(find: "-", with: "/"),
            options: RenameOptions(hideExtension: true), provider: FakeMetadataProvider())
        #expect(plan.first?.issue == .invalidName)
    }
}

@MainActor
@Suite("Smart Name on disk: filing into folders, and corrections")
struct SmartFilingOnDiskTests {
    private func makeModel(in sandbox: Sandbox, _ summaries: [String: DocumentSummary]) -> AppModel {
        let model = makeTestModel(
            provider: SystemFileMetadataProvider(), summarizer: FakeSummarizer(summaries: summaries),
            storeIn: sandbox.url("store"))
        model.step.kind = .smartName
        return model
    }

    @Test("filing makes the folder, ⌘Z takes it away again, and redo makes it again")
    func filingAndUndo() async throws {
        let sandbox = try Sandbox()
        sandbox.file("scan.pdf", contents: "the bill")
        let model = makeModel(
            in: sandbox, ["scan.pdf": DocumentSummary(title: "Electricity Bill", from: "Acme Energy")])
        model.step.smartTemplate = "{from}/{title}"
        model.add(urls: [sandbox.url("scan.pdf")])
        await model.analysis.waitUntilIdle()
        let undo = UndoManager()

        model.performRename(undoManager: undo)
        #expect(sandbox.contents(of: "Acme Energy/Electricity Bill.pdf") == "the bill")
        #expect(!sandbox.exists("scan.pdf"))

        undo.undo()
        #expect(sandbox.contents(of: "scan.pdf") == "the bill")
        #expect(!sandbox.exists("Acme Energy"))

        undo.redo()
        #expect(sandbox.contents(of: "Acme Energy/Electricity Bill.pdf") == "the bill")
    }

    @Test("a folder that already exists is used, and kept on undo")
    func existingFolderKept() async throws {
        let sandbox = try Sandbox(["Acme Energy/old.pdf", "scan.pdf"])
        let model = makeModel(
            in: sandbox, ["scan.pdf": DocumentSummary(title: "Electricity Bill", from: "Acme Energy")])
        model.step.smartTemplate = "{from}/{title}"
        model.add(urls: [sandbox.url("scan.pdf")])
        await model.analysis.waitUntilIdle()
        let undo = UndoManager()

        model.performRename(undoManager: undo)
        undo.undo()

        #expect(sandbox.exists("scan.pdf"))
        #expect(sandbox.exists("Acme Energy/old.pdf"))
    }

    @Test("a batch that fails takes away the folders it made")
    func failedBatchRemovesFolders() async throws {
        let sandbox = try Sandbox(["a.pdf", "b.pdf"])
        var moves = 0
        let model = makeTestModel(
            provider: SystemFileMetadataProvider(),
            summarizer: FakeSummarizer(summaries: [
                "a.pdf": DocumentSummary(title: "One", from: "Acme"),
                "b.pdf": DocumentSummary(title: "Two", from: "Bolt"),
            ]),
            storeIn: sandbox.url("store"),
            moveItem: { from, to in
                moves += 1
                if moves == 2 { throw CocoaError(.fileWriteNoPermission) }
                try FileManager.default.moveItem(at: from, to: to)
            })
        model.step.kind = .smartName
        model.step.smartTemplate = "{from}/{title}"
        model.add(urls: sandbox.urls(["a.pdf", "b.pdf"]))
        await model.analysis.waitUntilIdle()

        model.performRename(undoManager: nil)

        #expect(sandbox.exists("a.pdf") && sandbox.exists("b.pdf"))
        #expect(!sandbox.exists("Acme") && !sandbox.exists("Bolt"))
    }

    @Test("a corrected row is named from the correction, and a failed one can be named by hand")
    func correctionNamesTheRow() async throws {
        let sandbox = try Sandbox(["scan.pdf", "archive.zip"])
        let model = makeModel(in: sandbox, ["scan.pdf": DocumentSummary(title: "Electricty Bil")])
        model.step.smartTemplate = "{title}"
        model.add(urls: sandbox.urls(["scan.pdf", "archive.zip"]))
        await model.analysis.waitUntilIdle()

        model.analysis.correct(model.items[0].id, to: DocumentSummary(title: "Electricity Bill"))
        model.analysis.correct(model.items[1].id, to: DocumentSummary(title: "Photos 2025"))

        #expect(model.plan.map(\.proposedName) == ["Electricity Bill.pdf", "Photos 2025.zip"])
        #expect(model.analysis.status.isEmpty)
    }

    @Test("a row corrected before it is read is not then read over")
    func correctionBeatsTheRead() async throws {
        let sandbox = try Sandbox(["a.pdf", "b.pdf"])
        let summarizer = FakeSummarizer(titles: ["a.pdf": "Read First", "b.pdf": "Read Second"])
        let model = makeTestModel(summarizer: summarizer, storeIn: sandbox.url("store"))
        model.step.smartTemplate = "{title}"
        model.add(urls: sandbox.urls(["a.pdf", "b.pdf"]))
        model.step.kind = .smartName

        model.analysis.correct(model.items[1].id, to: DocumentSummary(title: "Typed Second"))
        await model.analysis.waitUntilIdle()

        #expect(model.plan.map(\.proposedName) == ["Read First.pdf", "Typed Second.pdf"])
        #expect(await summarizer.calls == ["a.pdf"])
    }
}

@Suite("Smart Name: the model's list of document types")
struct DocumentTypeTests {
    @Test("every type but 'other' has a word for {type}")
    func names() {
        #expect(DocumentType.bill.name == "Bill")
        #expect(DocumentType.other.name == nil)
        #expect(DocumentType.names.count == DocumentType.allCases.count - 1)
    }
}
