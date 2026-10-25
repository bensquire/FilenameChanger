import Foundation
import Testing

@testable import RenameKit

@Suite("Smart Name: a template filled from what reading the file found")
struct SmartNameTests {
    private func provider(
        _ name: String, title: String, from: String? = nil, date: Date?
    ) -> FakeMetadataProvider {
        FakeMetadataProvider(metadataByName: [
            name: FileMetadata(document: DocumentSummary(title: title, from: from, date: date))
        ])
    }

    @Test("the default template names a file by its date and title")
    func defaultTemplate() {
        let provider = provider("scan001.pdf", title: "Acme Invoice", date: localNoon(2026, 3, 3))
        let result = proposedName("scan001.pdf", .smartName(SmartNameConfig()), provider: provider)
        #expect(result == "20260303 - Acme Invoice.pdf")
    }

    @Test("with no date at all (not even the file's), {date} can't be filled, so the row is skipped")
    func noDateSkipsDateTemplates() {
        let provider = provider("notes.txt", title: "Meeting Notes", date: nil)
        #expect(proposedName("notes.txt", .smartName(SmartNameConfig()), provider: provider) == nil)
        let titleOnly = SmartNameConfig(template: "{title}")
        #expect(proposedName("notes.txt", .smartName(titleOnly), provider: provider) == "Meeting Notes.txt")
    }

    @Test("a file not yet read is left as it is")
    func unreadFileIsSkipped() {
        #expect(proposedName("scan001.pdf", .smartName(SmartNameConfig())) == nil)
    }

    @Test("a slash or colon in the title can't make a path")
    func titleIsMadeFileSafe() {
        let provider = provider("a.pdf", title: "Q1/Q2 Report:  Final ", date: localNoon(2026, 1, 2))
        let result = proposedName("a.pdf", .smartName(SmartNameConfig()), provider: provider)
        #expect(result == "20260102 - Q1-Q2 Report- Final.pdf")
    }

    @Test("{name} keeps the current name, and a title can't inject a token")
    func nameToken() {
        let provider = provider("IMG_42.png", title: "Receipt {name}", date: nil)
        let config = SmartNameConfig(template: "{title} ({name})", textCase: nil)
        let result = proposedName("IMG_42.png", .smartName(config), provider: provider)
        #expect(result == "Receipt {name} (IMG_42).png")
    }

    @Test("the extension is kept even with Hide Extensions off")
    func keepsExtension() {
        let provider = provider("a.pdf", title: "Bank Statement", date: localNoon(2026, 2, 28))
        let result = proposedName(
            "a.pdf", .smartName(SmartNameConfig()), options: RenameOptions(hideExtension: false),
            provider: provider)
        #expect(result == "20260228 - Bank Statement.pdf")
    }

    @Test("a custom date pattern formats the date")
    func customDatePattern() {
        let provider = provider("a.pdf", title: "Payslip", date: localNoon(2026, 4, 30))
        let config = SmartNameConfig(template: "{date} {title}", dateFormat: .custom("yyyy-MM"))
        #expect(proposedName("a.pdf", .smartName(config), provider: provider) == "2026-04 Payslip.pdf")
    }

    @Test("{from} names who sent the document")
    func fromToken() {
        let provider = provider(
            "a.pdf", title: "Electricity Bill", from: "Acme Energy", date: localNoon(2026, 3, 3))
        let config = SmartNameConfig(template: "{date} - {from} - {title}")
        #expect(
            proposedName("a.pdf", .smartName(config), provider: provider)
                == "20260303 - Acme Energy - Electricity Bill.pdf")
    }

    @Test(
        "a sender the document doesn't give drops out with its separator",
        arguments: [
            ("{date} - {from} - {title}", "20260303 - Electricity Bill.pdf"),
            ("{from} - {title}", "Electricity Bill.pdf"),
            ("{title} ({date}) - {from}", "Electricity Bill (20260303).pdf"),
            ("Scan {from} - {title}", "Scan - Electricity Bill.pdf"),
        ])
    func missingFromIsDropped(template: String, expected: String) {
        let provider = provider("a.pdf", title: "Electricity Bill", date: localNoon(2026, 3, 3))
        let config = SmartNameConfig(template: template)
        #expect(proposedName("a.pdf", .smartName(config), provider: provider) == expected)
    }

    @Test("a dropped token takes only its separator, never the punctuation of a value")
    func valuesKeepTheirPunctuation() {
        let provider = provider("a.pdf", title: "Smith & Co.", date: nil)
        let config = SmartNameConfig(template: "_{title} - {from}")
        #expect(proposedName("a.pdf", .smartName(config), provider: provider) == "_Smith & Co..pdf")
    }

    @Test("the Case setting re-cases what was read, and only that")
    func caseAppliesToReadValues() {
        let provider = provider(
            "a.pdf", title: "electricity bill", from: "ACME ENERGY LTD", date: localNoon(2026, 3, 3))
        let template = "{date} - {from} - {title} ({name})"

        func name(_ textCase: TextCase?) -> String? {
            proposedName(
                "a.pdf", .smartName(SmartNameConfig(template: template, textCase: textCase)),
                provider: provider)
        }

        #expect(name(.title) == "20260303 - Acme Energy Ltd - Electricity Bill (a).pdf")
        #expect(name(nil) == "20260303 - ACME ENERGY LTD - electricity bill (a).pdf")
        #expect(name(.snake) == "20260303 - acme_energy_ltd - electricity_bill (a).pdf")
    }
}
