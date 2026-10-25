import Foundation
import Testing

@testable import RenameApp
@testable import RenameKit

/// `PersistenceStore` round-trips presets, and — the safety-net — preserves an
/// undecodable file as `.bak` instead of letting the next save overwrite it.
@Suite("Persistence: round-trip and the .bak safety-net")
struct PersistenceTests {
    private final class TempDir {
        let url: URL
        init() throws {
            url = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("fnc-store-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        deinit { try? FileManager.default.removeItem(at: url) }
    }

    @Test("presets survive a save and reload")
    func presetsRoundTrip() throws {
        let temp = try TempDir()
        let store = PersistenceStore(directory: temp.url)
        let preset = Preset(
            name: "Add year", kind: .prepend, function: .prepend(text: "2026-"),
            options: RenameOptions(hideExtension: true))

        store.savePresets([preset])

        #expect(PersistenceStore(directory: temp.url).loadPresets() == [preset])
    }

    @Test("an undecodable presets file is backed up, not silently dropped")
    func corruptPresetsBackedUp() throws {
        let temp = try TempDir()
        let presets = temp.url.appendingPathComponent("presets.json")
        let backup = temp.url.appendingPathComponent("presets.json.bak")
        try Data("{ not valid json".utf8).write(to: presets)

        let loaded = PersistenceStore(directory: temp.url).loadPresets()

        #expect(loaded.isEmpty)  // couldn't decode → empty, not a crash
        #expect(FileManager.default.fileExists(atPath: backup.path))  // preserved
        #expect(try String(contentsOf: backup, encoding: .utf8) == "{ not valid json")
        // The original path is cleared, so the next save writes fresh.
        #expect(!FileManager.default.fileExists(atPath: presets.path))
    }

    @Test("a missing file loads as empty with no backup")
    func missingFileNoBackup() throws {
        let temp = try TempDir()
        let store = PersistenceStore(directory: temp.url)

        #expect(store.loadPresets().isEmpty)
        #expect(store.loadHistory().isEmpty)
        #expect(
            !FileManager.default.fileExists(
                atPath: temp.url.appendingPathComponent("presets.json.bak").path))
    }
}
