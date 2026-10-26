import Foundation
import RenameKit

/// UI-facing mode for Remove Characters.
public enum RemoveModeKind: String, CaseIterable, Sendable {
    case range
    case fromEnd
}

/// UI-facing mode for Insert Characters.
public enum InsertModeKind: String, CaseIterable, Sendable {
    case atIndex
    case fromEnd
}

/// UI-facing mode for the Date source.
public enum DateSourceKind: String, CaseIterable, Sendable {
    case custom
    case fileCreated
    case exif
}

/// A date format as the panel edits it: a preset, or a typed pattern that is
/// kept while the preset is in use, so switching back and forth loses neither.
/// Shared by Date and Smart Name.
public struct DateFormatFields: Equatable, Sendable {
    public var usePreset = true
    public var preset: DatePreset = .isoDash
    public var pattern = "yyyy-MM-dd"

    /// Starts from `choice`; a preset also seeds the pattern field with itself.
    public init(_ choice: DateFormatChoice) {
        if case let .preset(value) = choice { pattern = value.rawValue }
        load(choice)
    }

    public var choice: DateFormatChoice {
        usePreset ? .preset(preset) : .custom(pattern)
    }

    public mutating func load(_ choice: DateFormatChoice) {
        switch choice {
        case let .preset(value):
            usePreset = true
            preset = value
        case let .custom(value):
            usePreset = false
            pattern = value
        }
    }
}

/// One step of a rename as the panel edits it: which function, and the
/// editable fields of every function, so switching a step from Replace to
/// Sequence and back keeps what was typed for each.
public struct FunctionSettings: Equatable, Sendable {
    public var kind: FunctionKind = .prepend

    // Prepend / Append.
    public var prependText = ""
    public var appendText = ""

    // Replace family + wildcard + regex (find/replace reused across them).
    public var findText = ""
    public var replaceText = ""

    // Remove Characters.
    public var removeMode: RemoveModeKind = .range
    public var removeLocation = 0
    public var removeLength = 1
    public var removeFromEnd = 1

    // Insert Characters.
    public var insertText = ""
    public var insertMode: InsertModeKind = .atIndex
    public var insertIndex = 0
    public var padEnabled = false
    public var padLength = 1

    // Change Case.
    public var textCase: TextCase = .title

    // Clean Up.
    public var cleanUp = CleanUpConfig()

    // Sequence.
    public var sequence = SequenceConfig()

    // Date.
    public var dateSource: DateSourceKind = .fileCreated
    public var customDate = Date()
    public var dateFormat = DateFormatFields(.preset(.isoDash))
    public var datePlacement: Placement = .prepend

    // Smart Name: the template and how it fills in.
    public var smartTemplate = smartDefaults.template
    public var smartDateFormat = DateFormatFields(smartDefaults.dateFormat)
    public var smartTextCase = smartDefaults.textCase
    private static let smartDefaults = SmartNameConfig()

    public init(kind: FunctionKind = .prepend) {
        self.kind = kind
    }

    /// A step that edits `function`.
    public init(loading function: RenameFunction) {
        kind = FunctionKind(function)
        load(function)
    }

    /// The `RenameFunction` assembled from the kind and its fields.
    public var function: RenameFunction {
        switch kind {
        case .prepend: return .prepend(text: prependText)
        case .append: return .append(text: appendText)
        case .replaceFirst: return .replaceFirst(find: findText, with: replaceText)
        case .replaceLast: return .replaceLast(find: findText, with: replaceText)
        case .replaceAll: return .replaceAll(find: findText, with: replaceText)
        case .wildcard: return .wildcard(find: findText, with: replaceText)
        case .regex: return .regex(pattern: findText, template: replaceText)
        case .removeCharacters:
            switch removeMode {
            case .range: return .removeCharacters(.range(location: removeLocation, length: removeLength))
            case .fromEnd: return .removeCharacters(.fromEnd(count: removeFromEnd))
            }
        case .insertCharacters:
            let mode: InsertMode = insertMode == .atIndex ? .atIndex(insertIndex) : .fromEnd
            return .insertCharacters(text: insertText, mode: mode, padToLength: padEnabled ? padLength : nil)
        case .changeCase: return .changeCase(textCase)
        case .cleanUp: return .cleanUp(cleanUp)
        case .sequence: return .sequence(sequence)
        case .date: return .date(dateConfig)
        case .smartName:
            return .smartName(
                SmartNameConfig(
                    template: smartTemplate, dateFormat: smartDateFormat.choice, textCase: smartTextCase))
        }
    }

    private var dateConfig: DateConfig {
        let source: DateSource
        switch dateSource {
        case .custom: source = .custom(customDate)
        case .fileCreated: source = .fileCreated
        case .exif: source = .exif
        }
        return DateConfig(source: source, format: dateFormat.choice, placement: datePlacement)
    }

    /// Unpack a function value back into the editable fields.
    public mutating func load(_ function: RenameFunction) {
        switch function {
        case let .prepend(text): prependText = text
        case let .append(text): appendText = text
        case let .replaceFirst(find, with), let .replaceLast(find, with),
            let .replaceAll(find, with), let .wildcard(find, with):
            findText = find
            replaceText = with
        case let .regex(pattern, template):
            findText = pattern
            replaceText = template
        case let .removeCharacters(mode):
            switch mode {
            case let .range(location, length):
                removeMode = .range
                removeLocation = location
                removeLength = length
            case let .fromEnd(count):
                removeMode = .fromEnd
                removeFromEnd = count
            }
        case let .insertCharacters(text, mode, pad):
            insertText = text
            switch mode {
            case let .atIndex(index):
                insertMode = .atIndex
                insertIndex = index
            case .fromEnd:
                insertMode = .fromEnd
            }
            padEnabled = pad != nil
            if let pad { padLength = pad }
        case let .changeCase(value): textCase = value
        case let .cleanUp(config): cleanUp = config
        case let .sequence(config): sequence = config
        case let .date(config): loadDate(config)
        case let .smartName(config):
            smartTemplate = config.template
            smartDateFormat.load(config.dateFormat)
            smartTextCase = config.textCase
        }
    }

    private mutating func loadDate(_ config: DateConfig) {
        switch config.source {
        case let .custom(date):
            dateSource = .custom
            customDate = date
        case .fileCreated: dateSource = .fileCreated
        case .exif: dateSource = .exif
        }
        dateFormat.load(config.format)
        datePlacement = config.placement
    }
}
