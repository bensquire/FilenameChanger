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
