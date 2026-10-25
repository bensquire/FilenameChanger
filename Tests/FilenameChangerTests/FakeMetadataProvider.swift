import Foundation

@testable import RenameKit

/// A metadata provider the tests control: dates and "already on disk" names
/// are set per URL, so Sequence/Date and collision tests stay off the clock
/// and the real file system.
struct FakeMetadataProvider: FileMetadataProvider {
    var metadataByName: [String: FileMetadata] = [:]
    /// File names that should report as already existing on disk.
    var existingNames: Set<String> = []

    func metadata(for url: URL) -> FileMetadata {
        metadataByName[url.lastPathComponent] ?? FileMetadata()
    }

    func fileExists(at url: URL) -> Bool {
        existingNames.contains(url.lastPathComponent)
    }
}

/// Build file items under a throwaway directory from a list of names.
func items(_ names: [String], in directory: URL = URL(fileURLWithPath: "/tmp/fnc-test"))
    -> [FileItem]
{
    names.map { FileItem(url: directory.appending(component: $0)) }
}

/// The proposed name for the single file `name` under `function`, or nil if the
/// row is skipped/unchanged. A convenience for the one-file function tests.
func proposedName(
    _ name: String,
    _ function: RenameFunction,
    options: RenameOptions = RenameOptions(),
    provider: FakeMetadataProvider = FakeMetadataProvider()
) -> String? {
    let plan = RenameEngine.plan(
        items: items([name]), function: function, options: options, provider: provider)
    guard let row = plan.first, row.willRename, row.issue == nil else { return nil }
    return row.proposedName
}
