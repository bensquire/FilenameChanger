import AppKit
import Foundation

/// Presents the system open panel and expands the chosen items into files,
/// optionally walking folders one level deep or recursively. Also expands
/// folders dropped on the table or sent by the Finder Service, where there is
/// no panel mode to choose from.
@MainActor
public enum FileAdder {
    public enum Mode {
        /// Add exactly what is selected (files, or folders as-is).
        case items
        /// Add the top-level contents of selected folders.
        case folderContents
        /// Add every file inside selected folders and their subfolders.
        case recursive
    }

    public static func present(mode: Mode, completion: ([URL]) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = mode == .items
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        guard panel.runModal() == .OK else { return }
        completion(expand(panel.urls, mode: mode))
    }

    /// Expand URLs that arrive without a mode to choose — a drag-and-drop onto
    /// the table, or the Finder "Rename with FilenameChanger" Service. A real
    /// folder becomes the files inside it, recursively; plain files and
    /// packages (`.app`, `.rtfd`…) pass through as single items.
    public static func expandForDrop(_ urls: [URL]) -> [URL] {
        // Same as the panel's recursive mode, named for the drop/Service callers
        // so they don't borrow the panel's `Mode` vocabulary.
        expand(urls, mode: .recursive)
    }

    static func expand(_ urls: [URL], mode: Mode) -> [URL] {
        switch mode {
        case .items:
            return urls
        case .folderContents:
            return urls.flatMap { isExpandableDirectory($0) ? topLevelFiles(in: $0) : [$0] }
        case .recursive:
            return urls.flatMap { isExpandableDirectory($0) ? recursiveFiles(in: $0) : [$0] }
        }
    }

    /// A folder to descend into — a directory that is *not* a package. A
    /// package (`.app`, `.rtfd`, `.photoslibrary`…) is a directory on disk but
    /// a single item to the user, so it is renamed as one, never opened up.
    private static func isExpandableDirectory(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        return values?.isDirectory == true && values?.isPackage != true
    }

    // Both folder walks skip hidden files: `.DS_Store`, `.localized` and the
    // like are system metadata, not the user's files, and renaming them would
    // damage Finder state (and take a Sequence number from a real file).

    private static func topLevelFiles(in directory: URL) -> [URL] {
        let contents = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
            options: .skipsHiddenFiles)
        // Keep files and packages; drop only real sub-folders.
        return (contents ?? []).filter { !isExpandableDirectory($0) }
    }

    private static func recursiveFiles(in directory: URL) -> [URL] {
        // The error handler skips an unreadable item and keeps walking.
        guard
            let enumerator = FileManager.default.enumerator(
                at: directory, includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
                options: .skipsHiddenFiles, errorHandler: { _, _ in true })
        else { return [] }
        var files: [URL] = []
        for case let url as URL in enumerator {
            // Read both keys once (the enumerator has them prefetched) and
            // decide from the one fetch.
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
            if values?.isDirectory == true, values?.isPackage != true {
                continue  // a real folder: descend into it, don't add the folder itself
            }
            files.append(url)  // a file, or a package added as one item…
            if values?.isPackage == true { enumerator.skipDescendants() }  // …so don't walk into it
        }
        return files
    }
}
