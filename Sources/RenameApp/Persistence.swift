import Foundation
import RenameKit

/// A saved rename: a name, its steps, and the options in force.
public struct Preset: Identifiable, Codable, Sendable, Equatable {
    public var id: String { name }
    public var name: String
    /// The chain, in order. Never empty: a preset saved before chains is read
    /// as one step.
    public var steps: [RenameFunction]
    public var options: RenameOptions

    public init(name: String, steps: [RenameFunction], options: RenameOptions) {
        self.name = name
        self.steps = steps
        self.options = options
    }

    private enum CodingKeys: String, CodingKey {
        case name, steps, options
        // The one function a preset held before chains.
        case function
    }

    /// Reads both shapes, so presets saved before chains still load (an
    /// unreadable file would be set aside as `.bak`, losing them all).
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        options = try container.decode(RenameOptions.self, forKey: .options)
        if let steps = try container.decodeIfPresent([RenameFunction].self, forKey: .steps), !steps.isEmpty {
            self.steps = steps
        } else {
            steps = [try container.decode(RenameFunction.self, forKey: .function)]
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(steps, forKey: .steps)
        try container.encode(options, forKey: .options)
    }
}

extension FunctionKind: Codable {}

/// One past rename action: when it ran and the original → new names.
public struct HistoryEntry: Identifiable, Codable, Sendable, Equatable {
    /// Not `Identifiable`: names aren't unique within an entry (files in
    /// different folders can share a name), so views identify rows by index.
    public struct Row: Codable, Sendable, Equatable {
        public var original: String
        public var renamed: String

        public init(original: String, renamed: String) {
            self.original = original
            self.renamed = renamed
        }
    }

    public var id = UUID()
    public var date: Date
    public var rows: [Row]

    public init(id: UUID = UUID(), date: Date, rows: [Row]) {
        self.id = id
        self.date = date
        self.rows = rows
    }
}

/// Reads and writes presets and history as JSON under Application Support.
/// Dependency-free and injectable: tests point it at a temp directory.
public struct PersistenceStore: Sendable {
    private let directory: URL

    public init(directory: URL? = nil) {
        self.directory =
            directory
            ?? URL.applicationSupportDirectory.appending(
                component: "FilenameChanger", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(
            at: self.directory, withIntermediateDirectories: true)
    }

    private var presetsURL: URL { directory.appending(component: "presets.json") }
    private var historyURL: URL { directory.appending(component: "history.json") }

    public func loadPresets() -> [Preset] { load([Preset].self, from: presetsURL) ?? [] }
    public func savePresets(_ presets: [Preset]) { save(presets, to: presetsURL) }
    public func loadHistory() -> [HistoryEntry] { load([HistoryEntry].self, from: historyURL) ?? [] }
    public func saveHistory(_ history: [HistoryEntry]) { save(history, to: historyURL) }

    private func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }  // no file: nothing to load
        if let value = try? JSONDecoder().decode(type, from: data) { return value }
        // The file exists but won't decode — corrupt, or an older/newer schema.
        // Move it aside to a `.bak` rather than let the next save overwrite it,
        // so the user's presets/history are recoverable instead of silently lost.
        let backup = url.appendingPathExtension("bak")
        try? FileManager.default.removeItem(at: backup)  // replace any previous backup
        try? FileManager.default.moveItem(at: url, to: backup)
        return nil
    }

    private func save<T: Encodable>(_ value: T, to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
