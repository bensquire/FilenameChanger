import AppIntents
import Foundation
import RenameKit

/// FilenameChanger's actions in Shortcuts. With them, a shortcut, or a folder
/// automation that runs one when a scan lands, can rename files without the
/// window: with a saved preset, which can be a whole chain, or with Smart
/// Name alone. They run in the background, and the window's own files and
/// settings stay as they were. A dialog would stop an automation to wait for
/// someone, so the actions return the renamed files instead of saying anything.
///
/// The metadata Shortcuts reads is extracted by `bundle.sh`, as Xcode would.
/// /documentation/appintents/appintentspackage
public struct RenameAppPackage: AppIntentsPackage {}

/// A saved preset, as Shortcuts lists it to choose from.
public struct PresetEntity: AppEntity {
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Preset"
    public static let defaultQuery = PresetQuery()

    /// The preset's name: names are unique, and saving under a name replaces
    /// the preset that had it.
    public let id: String
    public var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(id)") }

    public init(id: String) {
        self.id = id
    }
}

/// The presets saved in the app.
/// /documentation/appintents/entityquery
public struct PresetQuery: EntityQuery {
    @Dependency private var model: AppModel

    public init() {}

    @MainActor
    public func entities(for identifiers: [String]) async throws -> [PresetEntity] {
        try await suggestedEntities().filter { identifiers.contains($0.id) }
    }

    @MainActor
    public func suggestedEntities() async throws -> [PresetEntity] {
        model.presets.map { PresetEntity(id: $0.name) }
    }
}

/// Rename files with a saved preset: every step of it, with its options.
public struct RenameWithPresetIntent: AppIntent {
    public static let title: LocalizedStringResource = "Rename Files with Preset"
    public static let description = IntentDescription(
        "Renames files with a preset saved in FilenameChanger. A file the preset wouldn’t change, or can’t name, is left as it is.",
        categoryName: "Renaming")
    /// /documentation/appintents/appintent/supportedmodes
    public static let supportedModes: IntentModes = .background

    @Parameter(title: "Files", supportedContentTypes: [.item])
    public var files: [IntentFile]

    @Parameter(title: "Preset")
    public var preset: PresetEntity

    @Dependency private var model: AppModel

    public init() {}

    public static var parameterSummary: some ParameterSummary {
        Summary("Rename \(\.$files) with \(\.$preset)")
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<[IntentFile]> {
        guard let saved = model.presets.first(where: { $0.name == preset.id }) else {
            throw OutsideRenameError("There’s no preset called “\(preset.id)” any more.")
        }
        return .result(value: try await model.rename(files, steps: saved.steps, options: saved.options))
    }
}

/// Name documents from their contents, with a Smart Name template.
public struct SmartNameIntent: AppIntent {
    public static let title: LocalizedStringResource = "Smart Name Files"
    public static let description = IntentDescription(
        "Reads each document with Apple Intelligence, on this Mac, and names it from a template: {date}, {title}, {from}, {type} and {name}. A / in the template files the document into a folder.",
        categoryName: "Renaming")
    public static let supportedModes: IntentModes = .background

    @Parameter(title: "Files", supportedContentTypes: [.item])
    public var files: [IntentFile]

    @Parameter(title: "Template", default: "{date} - {title}")
    public var template: String

    @Dependency private var model: AppModel

    public init() {}

    public static var parameterSummary: some ParameterSummary {
        Summary("Smart Name \(\.$files) as \(\.$template)")
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<[IntentFile]> {
        let steps: [RenameFunction] = [.smartName(SmartNameConfig(template: template))]
        return .result(
            value: try await model.rename(files, steps: steps, options: RenameOptions(hideExtension: true)))
    }
}

/// Bring files into the window, to rename them there by eye.
public struct OpenInFilenameChangerIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open Files in FilenameChanger"
    public static let description = IntentDescription(
        "Adds files to FilenameChanger’s window, to rename them there.", categoryName: "Renaming")
    public static let supportedModes: IntentModes = .foreground(.immediate)

    @Parameter(title: "Files", supportedContentTypes: [.item])
    public var files: [IntentFile]

    @Dependency private var model: AppModel

    public init() {}

    public static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$files) in FilenameChanger")
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        model.add(urls: FileAdder.expandForDrop(files.compactMap(\.originalFileURL)))
        return .result()
    }
}

extension AppModel {
    /// Rename the files Shortcuts handed over, holding their access open for
    /// the whole batch, and hand back where each one is now.
    fileprivate func rename(
        _ files: [IntentFile], steps: [RenameFunction], options: RenameOptions
    ) async throws -> [IntentFile] {
        // Files shared from elsewhere are reached through security scope, on the
        // URL as it was handed over. /documentation/appintents/intentfile/fileurl
        let accessing = files.compactMap(\.fileURL).filter { $0.startAccessingSecurityScopedResource() }
        defer { accessing.forEach { $0.stopAccessingSecurityScopedResource() } }
        let outcome = try await rename(files.compactMap(\.originalFileURL), steps: steps, options: options)
        return outcome.files.map { IntentFile(fileURL: $0) }
    }
}

extension IntentFile {
    /// The file's own location. Shortcuts hands Finder files over as
    /// "/.nofollow/Users/…" (seen on macOS 27.0.1); that prefix would end up
    /// in the history and the table, so it comes off.
    var originalFileURL: URL? {
        guard let url = fileURL else { return nil }
        let path = url.path(percentEncoded: false)
        guard path.hasPrefix("/.nofollow/") else { return url }
        return URL(filePath: String(path.dropFirst("/.nofollow".count)))
    }
}
