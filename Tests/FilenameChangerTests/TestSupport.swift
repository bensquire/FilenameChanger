import Foundation

@testable import RenameApp
@testable import RenameIntelligence
@testable import RenameKit

/// A fresh temp folder for one test, holding real files; removed when the test
/// lets go of it.
final class Sandbox {
    let root: URL

    /// Creates the folder and an empty file at each path (sub-folders made as
    /// needed).
    init(_ paths: [String] = []) throws {
        root = URL(filePath: NSTemporaryDirectory())
            .appending(component: "fnc-test-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for path in paths { file(path) }
    }

    deinit { try? FileManager.default.removeItem(at: root) }

    func url(_ path: String) -> URL { root.appending(path: path) }
    func urls(_ paths: [String]) -> [URL] { paths.map(url) }

    /// Write a file, replacing any already there. Distinctive `contents` let a
    /// test prove a file survived (or wasn't clobbered by) a rename.
    @discardableResult func file(_ path: String, contents: String = "") -> URL {
        let url = url(path)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: url.path(percentEncoded: false), contents: Data(contents.utf8))
        return url
    }

    @discardableResult func directory(_ path: String) -> URL {
        let url = url(path)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func exists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: url(path).path(percentEncoded: false))
    }

    func contents(of path: String) -> String? {
        try? String(contentsOf: url(path), encoding: .utf8)
    }
}

/// An `AppModel` for a test: presets and history in a throwaway folder, and
/// fakes for metadata and the document reader unless a test passes real ones.
@MainActor
func makeTestModel(
    provider: FileMetadataProvider = FakeMetadataProvider(),
    summarizer: DocumentSummarizer = FakeSummarizer(titles: [:]),
    storeIn directory: URL = URL(filePath: NSTemporaryDirectory())
        .appending(component: "fnc-store-\(UUID().uuidString)"),
    moveItem: @escaping (URL, URL) throws -> Void = { try FileManager.default.moveItem(at: $0, to: $1) }
) -> AppModel {
    AppModel(
        provider: provider, store: PersistenceStore(directory: directory), summarizer: summarizer,
        moveItem: moveItem)
}

/// A reader the tests control: what each file name says it is, or a
/// failure, and a record of every file it was asked to read.
actor FakeSummarizer: DocumentSummarizer {
    nonisolated let availability: ModelAvailability
    private let summaries: [String: DocumentSummary]
    private(set) var calls: [String] = []

    init(summaries: [String: DocumentSummary], availability: ModelAvailability = .available) {
        self.summaries = summaries
        self.availability = availability
    }

    /// A title per file name, and nothing else.
    init(titles: [String: String], availability: ModelAvailability = .available) {
        self.init(summaries: titles.mapValues { DocumentSummary(title: $0) }, availability: availability)
    }

    /// The "text" of a file is its name, so `summarize` can look it up.
    nonisolated func extractText(from url: URL) async throws -> String {
        url.lastPathComponent
    }

    func summarize(_ text: String, of url: URL) async throws -> DocumentSummary {
        calls.append(text)
        guard let summary = summaries[text] else { throw DocumentText.Failure.noText }
        return summary
    }
}

/// Noon on that day in the local time zone. DateStamp formats in the local
/// zone, so the stamp reads that day on every machine — from UTC+14 to
/// UTC−12, where a fixed UTC instant would land a day early or late.
func localNoon(_ year: Int, _ month: Int, _ day: Int) -> Date {
    let components = DateComponents(
        timeZone: .autoupdatingCurrent, year: year, month: month, day: day, hour: 12)
    return Calendar(identifier: .gregorian).date(from: components) ?? Date(timeIntervalSince1970: 0)
}
