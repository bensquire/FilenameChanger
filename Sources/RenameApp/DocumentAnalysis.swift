import Foundation
import Observation
import RenameIntelligence
import RenameKit

/// Smart Name's reading queue: each file is read once, in the background, and
/// what was found is kept for the plan to name it from. Keyed by the row's id
/// rather than its URL, so renaming a file (or undoing that) never reads it
/// again.
@MainActor
@Observable
public final class DocumentAnalysis {
    public enum Status: Equatable, Sendable {
        /// Waiting to be read, or being read.
        case pending
        case failed(String)
    }

    public private(set) var summaries: [FileItem.ID: DocumentSummary] = [:]
    /// Rows not yet read, or that couldn't be. A row with a summary has no
    /// status.
    public private(set) var status: [FileItem.ID: Status] = [:]

    private let summarizer: DocumentSummarizer
    /// Waiting to be read, oldest first.
    private var queue: [(id: FileItem.ID, url: URL)] = []
    private var worker: Task<Void, Never>?

    public init(summarizer: DocumentSummarizer) {
        self.summarizer = summarizer
    }

    /// Whether the model can read files on this Mac right now. Read live: it
    /// changes as Apple Intelligence is turned on or finishes downloading.
    public var availability: ModelAvailability { summarizer.availability }

    /// Rows still to be read, for the "Reading 3 documents" progress line.
    public var pendingCount: Int {
        status.values.count { $0 == .pending }
    }

    /// Queue every row not already read, queued or failed — while the model
    /// is available. Rows are read one at a time: the on-device model answers
    /// one request at a time.
    public func analyze(_ items: [FileItem]) {
        guard availability == .available else { return }
        for item in items where summaries[item.id] == nil && status[item.id] == nil {
            status[item.id] = .pending
            queue.append((item.id, item.url))
        }
        guard worker == nil, !queue.isEmpty else { return }
        worker = Task { await drain() }
    }

    /// Put what the person says a document is in place of what was read — or
    /// of a read that failed, or one not yet done, which is then not read.
    public func correct(_ id: FileItem.ID, to summary: DocumentSummary) {
        queue.removeAll { $0.id == id }
        summaries[id] = summary
        status[id] = nil
    }

    /// Drop what was found for these rows, and stop waiting to read them.
    public func forget(_ ids: Set<FileItem.ID>) {
        queue.removeAll { ids.contains($0.id) }
        for id in ids {
            summaries[id] = nil
            status[id] = nil
        }
    }

    public func cancelAll() {
        worker?.cancel()
        worker = nil
        queue.removeAll()
        summaries.removeAll()
        status.removeAll()
    }

    /// Wait for the queue to empty — for tests, which can't watch the table.
    func waitUntilIdle() async {
        await worker?.value
    }

    /// Read the queue in order. The model answers one file at a time, but
    /// getting a file's text (OCR, for a scan) doesn't need it, so the next
    /// file's text is got while the model answers for this one.
    private func drain() async {
        var upcoming = takeNext()
        defer { upcoming?.text.cancel() }  // stopped early: drop the look-ahead
        while let current = upcoming, !Task.isCancelled {
            upcoming = takeNext()
            let result: Result<DocumentSummary, Error>
            do {
                let text = try await current.text.value
                // Removed while its text was being got: don't spend the model on it.
                guard status[current.id] == .pending else { continue }
                result = .success(try await summarizer.summarize(text, of: current.url))
            } catch {
                result = .failure(error)
            }
            // Forgotten (removed, or the list cleared) while it was being read.
            guard !Task.isCancelled, status[current.id] == .pending else { continue }
            switch result {
            case let .success(summary):
                summaries[current.id] = summary
                status[current.id] = nil
            case let .failure(error):
                status[current.id] = .failed(error.localizedDescription)
            }
        }
        if !Task.isCancelled { worker = nil }
    }

    /// The next row off the queue, with its text already being got.
    private func takeNext() -> (id: FileItem.ID, url: URL, text: Task<String, Error>)? {
        guard !queue.isEmpty else { return nil }
        let next = queue.removeFirst()
        let summarizer = summarizer
        return (next.id, next.url, Task { try await summarizer.extractText(from: next.url) })
    }
}
