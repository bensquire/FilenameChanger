import Foundation
import FoundationModels
import RenameKit

/// Reads a file and says what it is: its title, sender and date. The seam the
/// app reads documents through, so tests pass a fake rather than the model.
/// Two steps, so a batch can get the next file's text while the model is
/// still answering for this one.
public protocol DocumentSummarizer: Sendable {
    /// Whether `summarize` can run now.
    var availability: ModelAvailability { get }
    /// The text the file shows: slow for a scan (OCR), but needs no model.
    func extractText(from url: URL) async throws -> String
    /// Ask the model about `text`, read from the file at `url`.
    func summarize(_ text: String, of url: URL) async throws -> DocumentSummary
}

/// Whether Smart Name can run on this Mac, and if not, what the person can do.
public enum ModelAvailability: Sendable, Equatable {
    case available
    case appleIntelligenceOff
    case modelNotReady
    case deviceNotEligible

    /// Why Smart Name can't run, in words for the person; nil when it can.
    public var explanation: String? {
        switch self {
        case .available: return nil
        case .appleIntelligenceOff:
            return "Turn on Apple Intelligence in System Settings to use Smart Name."
        case .modelNotReady:
            return "Apple Intelligence is still getting ready. Try again once it has finished downloading."
        case .deviceNotEligible: return "Smart Name needs a Mac that supports Apple Intelligence."
        }
    }
}

/// Smart Name's reader: the on-device Apple Intelligence model, so a
/// document's contents never leave the Mac. A fresh session per file, since
/// each file is its own question and the context window is small.
public struct AppleIntelligenceSummarizer: DocumentSummarizer {
    public init() {}

    /// The system model's state, now.
    /// /documentation/foundationmodels/systemlanguagemodel/availability-swift.property
    public var availability: ModelAvailability {
        switch SystemLanguageModel.default.availability {
        case .available: return .available
        case .unavailable(.appleIntelligenceNotEnabled): return .appleIntelligenceOff
        case .unavailable(.deviceNotEligible): return .deviceNotEligible
        case .unavailable: return .modelNotReady
        }
    }

    public func extractText(from url: URL) async throws -> String {
        try await DocumentText.extract(from: url)
    }

    /// Off the main actor, explicitly: the model's answer is slow.
    @concurrent
    public func summarize(_ text: String, of url: URL) async throws -> DocumentSummary {
        let facts: DocumentFacts
        do {
            facts = try await ask(about: text)
        } catch let error where Self.exceedsContext(error) {
            // Dense text can run past the budget; the start alone still names it.
            facts = try await ask(about: String(text.prefix(text.count / 2)))
        }
        // As the model wrote it: Smart Name's Case setting re-cases it.
        let title = facts.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw DocumentText.Failure.noText }
        let from = facts.from.trimmingCharacters(in: .whitespacesAndNewlines)
        return DocumentSummary(
            title: String(title.prefix(80)), from: from.isEmpty ? nil : String(from.prefix(60)),
            // The document's own date, else the file's: every read row gets one.
            date: Self.date(from: facts.date)
                ?? (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate)
    }

    private func ask(about text: String) async throws -> DocumentFacts {
        let session = LanguageModelSession(instructions: Self.instructions)
        return try await session.respond(
            to: "Document:\n\(text)", generating: DocumentFacts.self
        ).content
    }

    /// Whether the prompt ran past the context window. macOS 27 throws
    /// `LanguageModelError` for it (checked on 27.0.1); macOS 26 has only the
    /// older `GenerationError`, which 27 deprecates.
    /// /documentation/foundationmodels/languagemodelerror/contextsizeexceeded(_:)
    private static func exceedsContext(_ error: any Error) -> Bool {
        if #available(macOS 27, *), case LanguageModelError.contextSizeExceeded = error { return true }
        if case LanguageModelSession.GenerationError.exceededContextWindowSize = error { return true }
        return false
    }

    private static let instructions = """
        You name files. Read the start of a document and give what it is, who sent or \
        issued it, and the date it was issued or written. Use only the document.
        """

    /// "YYYY-MM-DD" as noon on that day where the person is, so formatting it
    /// in their time zone can never land on the day before or after. Anything
    /// else, or a year no document plausibly has, is no date.
    static func date(from text: String, calendar: Calendar = .autoupdatingCurrent) -> Date? {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1900...2200).contains(parts[0]) else { return nil }
        let components = DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12)
        guard components.isValidDate(in: calendar) else { return nil }
        return calendar.date(from: components)
    }
}

/// What the model is asked for: three plain fields, so the schema costs few
/// tokens. /documentation/foundationmodels/generating-swift-data-structures-with-guided-generation
@Generable
struct DocumentFacts {
    @Guide(
        description: "What the document is, 2 to 6 words, worded as the document puts it, no date or sender")
    var title: String
    @Guide(description: "The company, organisation or person that sent or issued it, or empty")
    var from: String
    @Guide(description: "The date the document was issued or written, as YYYY-MM-DD, or empty if none")
    var date: String
}
