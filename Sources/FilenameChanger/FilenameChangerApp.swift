import AppIntents
import RenameApp
import SwiftUI

@main
struct FilenameChangerApp: App {
    // The delegate composes the app (it owns the one model) and receives
    // files from Finder: Open With, the Dock icon and the Service.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // Single Window, not WindowGroup: one shared model, and Finder
        // open-document events should not spawn clone windows.
        Window("FilenameChanger", id: "main") {
            ContentView(model: delegate.model)
        }
        .commands {
            FileCommands(model: delegate.model)
        }
    }
}

/// The app's Shortcuts actions live in `RenameApp`; this brings them in.
/// /documentation/appintents/appintentspackage
struct FilenameChangerPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] { [RenameAppPackage.self] }
}

/// The actions Shortcuts offers ready-made, with nothing to set up. Here, not
/// in `RenameApp`: a provider in a library is dropped from the app's metadata.
/// /documentation/appintents/appshortcutsprovider
struct FilenameChangerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SmartNameIntent(), phrases: ["Smart Name files with \(.applicationName)"],
            shortTitle: "Smart Name Files", systemImageName: "apple.intelligence")
        AppShortcut(
            intent: RenameWithPresetIntent(), phrases: ["Rename files with \(.applicationName)"],
            shortTitle: "Rename with Preset", systemImageName: "character.cursor.ibeam")
    }
}
