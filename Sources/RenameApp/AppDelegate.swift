import AppIntents
import AppKit
import Foundation

/// Where the app is composed, and where files arrive from Finder. One window,
/// so one model; the delegate exists before the scene and outlives every
/// view, so it makes the model and the scene hands it on.
///
/// Files reach the app three ways besides the window itself: Open With (the
/// document type Info.plist declares), a drop on the Dock icon, and the
/// "Rename with FilenameChanger" Service. All three add to the list.
@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public let model: AppModel

    /// Handed a model by tests; the app's own comes from `init()`.
    public init(model: AppModel) {
        self.model = model
        super.init()
    }

    /// The one `NSApplicationDelegateAdaptor` calls. It hands the model to
    /// the Shortcuts actions, before any can run: one may launch the app in
    /// the background. Two dev shortcuts: `FILENAMECHANGER_FOLDER=/path`
    /// pre-loads that folder's files so the table is populated without the
    /// open panel, and `FILENAMECHANGER_STORE=/path` keeps presets and history
    /// there instead of Application Support, so a trial run leaves the real
    /// ones alone.
    /// /documentation/appintents/appdependencymanager
    override public convenience init() {
        let environment = ProcessInfo.processInfo.environment
        let store = PersistenceStore(
            directory: environment["FILENAMECHANGER_STORE"].map {
                URL(filePath: $0, directoryHint: .isDirectory)
            })
        let model = AppModel(store: store)
        AppDependencyManager.shared.add(dependency: model)
        if let path = environment["FILENAMECHANGER_FOLDER"] {
            let folder = URL(filePath: path, directoryHint: .isDirectory)
            model.add(urls: FileAdder.expand([folder], mode: .folderContents))
        }
        self.init(model: model)
    }

    /// Open With, `open -a` and a drop on the Dock icon. A folder becomes the
    /// files inside it, as a drop on the window does.
    /// /documentation/appkit/nsapplicationdelegate/application(_:open:)
    public func application(_ application: NSApplication, open urls: [URL]) {
        model.add(urls: FileAdder.expandForDrop(urls))
    }

    /// Set once launched: "Service requests can arrive immediately after the
    /// service provider is set", so only when the app is ready for them.
    /// /documentation/appkit/nsapplication/servicesprovider
    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.servicesProvider = self
    }

    /// Coming back to the app is when Apple Intelligence may have finished
    /// setting up, so Smart Name tries reading again.
    public func applicationDidBecomeActive(_ notification: Notification) {
        model.analyzeIfNeeded()
    }

    /// One window: closing it ends the session, so a later Open With starts a
    /// fresh launch with a window, rather than adding files to a list that
    /// nothing shows.
    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// The `NSMessage` named in Info.plist. The signature is fixed by the
    /// Services API.
    @objc public func renameFiles(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        guard
            let urls = pasteboard.readObjects(
                forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
            !urls.isEmpty
        else {
            error.pointee = "FilenameChanger was sent no files."
            return
        }
        model.add(urls: FileAdder.expandForDrop(urls))
        // The user asked for this app from Finder's menu, so come forward.
        // /documentation/appkit/nsapplication/activate()
        NSApplication.shared.activate()
    }
}
