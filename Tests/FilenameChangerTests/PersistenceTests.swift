import Foundation
import Testing

@testable import RenameApp
@testable import RenameKit

/// `PersistenceStore` round-trips presets, and — the safety-net — preserves an
/// undecodable file as `.bak` instead of letting the next save overwrite it.
@Suite("Persistence: round-trip and the .bak safety-net")
struct PersistenceTests {
    @Test("presets survive a save and reload")
    func presetsRoundTrip() throws {
        let temp = try Sandbox()
        let store = PersistenceStore(directory: temp.root)
        let preset = Preset(
            name: "Add year", steps: [.prepend(text: "2026-")], options: RenameOptions(hideExtension: true))

        store.savePresets([preset])

        #expect(PersistenceStore(directory: temp.root).loadPresets() == [preset])
    }

    @Test("an undecodable presets file is backed up, not silently dropped")
    func corruptPresetsBackedUp() throws {
        let temp = try Sandbox()
        let presets = temp.url("presets.json")
        let backup = temp.url("presets.json.bak")
        try Data("{ not valid json".utf8).write(to: presets)

        let loaded = PersistenceStore(directory: temp.root).loadPresets()

        #expect(loaded.isEmpty)  // couldn't decode → empty, not a crash
        #expect(temp.exists("presets.json.bak"))  // preserved
        #expect(try String(contentsOf: backup, encoding: .utf8) == "{ not valid json")
        // The original path is cleared, so the next save writes fresh.
        #expect(!temp.exists("presets.json"))
    }

    @Test("a missing file loads as empty with no backup")
    func missingFileNoBackup() throws {
        let temp = try Sandbox()
        let store = PersistenceStore(directory: temp.root)

        #expect(store.loadPresets().isEmpty)
        #expect(store.loadHistory().isEmpty)
        #expect(
            !temp.exists("presets.json.bak"))
    }
}
