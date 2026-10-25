import Foundation

/// Context handed to a function for one row.
public struct ItemContext: Sendable {
    /// Zero-based position in the working order (after any sequence sort).
    public let index: Int
    public let metadata: FileMetadata
    public let options: RenameOptions

    public init(index: Int, metadata: FileMetadata, options: RenameOptions) {
        self.index = index
        self.metadata = metadata
        self.options = options
    }
}

/// Letter-case transforms for Change Case. The first three operate on the raw
/// text; the rest split it into words (on separators and camelCase boundaries)
/// and rejoin them in the chosen convention.
public enum TextCase: String, Sendable, CaseIterable, Codable {
    case title
    case lower
    case upper
    case snake
    case kebab
    case camel
    case pascal
    case screamingSnake

    /// Transform a name's base into this case.
    func apply(to text: String) -> String {
        switch self {
        case .title: return text.localizedCapitalized
        case .lower: return text.localizedLowercase
        case .upper: return text.localizedUppercase
        case .snake: return join(text, with: "_") { $0.localizedLowercase }
        case .kebab: return join(text, with: "-") { $0.localizedLowercase }
        case .screamingSnake: return join(text, with: "_") { $0.localizedUppercase }
        case .camel: return camel(text, upperFirst: false)
        case .pascal: return camel(text, upperFirst: true)
        }
    }

    /// The styles that split the name into words. They treat a "." as a word
    /// separator, so they must only ever see the name *without* its extension —
    /// otherwise snake/kebab/… would fold ".jpg" into the name and destroy it.
    /// Title/lower/upper, by contrast, may case the extension (honouring the
    /// Hide Extensions option).
    var operatesOnWords: Bool {
        switch self {
        case .title, .lower, .upper: return false
        case .snake, .kebab, .camel, .pascal, .screamingSnake: return true
        }
    }

    /// Lower/upper each word and join with `separator`. A name with no letters
    /// or digits yields no words; it is returned unchanged so the row skips
    /// rather than becoming empty.
    private func join(
        _ text: String, with separator: String, _ transform: (String) -> String
    ) -> String {
        let words = Self.words(in: text)
        return words.isEmpty ? text : words.map(transform).joined(separator: separator)
    }

    private func camel(_ text: String, upperFirst: Bool) -> String {
        let words = Self.words(in: text)
        guard !words.isEmpty else { return text }
        return words.enumerated()
            .map { index, word in
                index == 0 && !upperFirst ? word.localizedLowercase : Self.capitalized(word)
            }
            .joined()
    }

    private static func capitalized(_ word: String) -> String {
        guard let first = word.first else { return word }
        return first.uppercased() + String(word.dropFirst()).localizedLowercase
    }

    /// Split into words on any non-alphanumeric character and at camelCase
    /// boundaries, including the end of an acronym ("XMLFile" → "XML", "File").
    private static func words(in text: String) -> [String] {
        var words: [String] = []
        var current = ""
        let chars = Array(text)
        func flush() {
            if !current.isEmpty { words.append(current) }
            current = ""
        }
        for (index, ch) in chars.enumerated() {
            guard ch.isLetter || ch.isNumber else {
                flush()
                continue
            }
            if let last = current.last {
                let camelBoundary = last.isLowercase && ch.isUppercase
                let acronymEnd =
                    last.isUppercase && ch.isUppercase
                    && index + 1 < chars.count && chars[index + 1].isLowercase
                if camelBoundary || acronymEnd { flush() }
            }
            current.append(ch)
        }
        flush()
        return words
    }
}

/// How Remove Characters chooses what to drop.
public enum RemoveMode: Sendable, Equatable, Codable {
    /// Remove `length` characters starting at `location` (0-based).
    case range(location: Int, length: Int)
    /// Remove `count` characters from the end.
    case fromEnd(count: Int)
}

/// Where Insert Characters puts the text.
public enum InsertMode: Sendable, Equatable, Codable {
    case atIndex(Int)
    case fromEnd
}

/// Sort order for Sequence numbering. `custom` keeps the table's own order.
public enum SequenceSort: String, Sendable, CaseIterable, Codable {
    case custom
    case alphabetical
    case fileDate
    case exifDate
}

/// Where the sequence name sits relative to the index digits.
public enum NamePosition: String, Sendable, CaseIterable, Codable {
    case before
    case after
}

public struct SequenceConfig: Sendable, Equatable, Codable {
    public var name: String
    public var namePosition: NamePosition
    public var placement: Placement
    public var digits: Int
    public var start: Int
    public var sort: SequenceSort
    public var ascending: Bool

    public init(
        name: String = "", namePosition: NamePosition = .before, placement: Placement = .replaceAll,
        digits: Int = 3, start: Int = 1, sort: SequenceSort = .custom, ascending: Bool = true
    ) {
        self.name = name
        self.namePosition = namePosition
        self.placement = placement
        self.digits = digits
        self.start = start
        self.sort = sort
        self.ascending = ascending
    }
}

/// Which date a Date rename stamps on.
public enum DateSource: Sendable, Equatable, Codable {
    case custom(Date)
    case fileCreated
    case exif
}

/// Six presets, or a custom Unicode (UTS#35) pattern typed by the user.
public enum DateFormatChoice: Sendable, Equatable, Codable {
    case preset(DatePreset)
    case custom(String)
}

public enum DatePreset: String, Sendable, CaseIterable, Codable {
    case isoDash = "yyyy-MM-dd"
    case usSlash = "MM-dd-yyyy"
    case euDash = "dd-MM-yyyy"
    case compact = "yyyyMMdd"
    case underscored = "yyyy_MM_dd"
    case longText = "MMM d, yyyy"
}

public struct DateConfig: Sendable, Equatable, Codable {
    public var source: DateSource
    public var format: DateFormatChoice
    public var placement: Placement

    public init(
        source: DateSource = .fileCreated,
        format: DateFormatChoice = .preset(.isoDash),
        placement: Placement = .prepend
    ) {
        self.source = source
        self.format = format
        self.placement = placement
    }
}

/// Tidy-up toggles for the Clean Up function, applied in a fixed order:
/// collapse runs of whitespace, replace spaces, strip accents, then remove
/// characters that are unsafe in a file name.
public struct CleanUpConfig: Sendable, Equatable, Codable {
    public var collapseWhitespace: Bool
    public var replaceSpaces: Bool
    public var spaceReplacement: String
    public var removeDiacritics: Bool
    public var removeIllegal: Bool

    public init(
        collapseWhitespace: Bool = true, replaceSpaces: Bool = true,
        spaceReplacement: String = "_", removeDiacritics: Bool = false,
        removeIllegal: Bool = true
    ) {
        self.collapseWhitespace = collapseWhitespace
        self.replaceSpaces = replaceSpaces
        self.spaceReplacement = spaceReplacement
        self.removeDiacritics = removeDiacritics
        self.removeIllegal = removeIllegal
    }
}

/// The rename behaviours, one case each. Adding a behaviour is a new case and
/// its arm in `proposedBaseName` — never a flag threaded through the others.
public enum RenameFunction: Sendable, Equatable, Codable {
    case prepend(text: String)
    case append(text: String)
    case replaceFirst(find: String, with: String)
    case replaceLast(find: String, with: String)
    case replaceAll(find: String, with: String)
    case wildcard(find: String, with: String)
    case regex(pattern: String, template: String)
    case removeCharacters(RemoveMode)
    case insertCharacters(text: String, mode: InsertMode, padToLength: Int?)
    case changeCase(TextCase)
    case sequence(SequenceConfig)
    case date(DateConfig)
    case cleanUp(CleanUpConfig)

    /// Whether this function must keep the file extension intact even when Hide
    /// Extensions is off. The word-splitting Change Case styles do — otherwise
    /// they would fold the extension into the name — so the engine always
    /// splits the extension off before applying them.
    public var preservesExtension: Bool {
        if case let .changeCase(textCase) = self { return textCase.operatesOnWords }
        return false
    }

    /// Whether `proposedBaseName` reads the file's metadata — only a Date
    /// stamp taken from the file or its EXIF does. The engine skips the
    /// metadata read for everything else.
    var readsMetadata: Bool {
        guard case let .date(config) = self else { return false }
        if case .custom = config.source { return false }
        return true
    }

    /// The proposed name for the working string `base` (the name without its
    /// extension when Hide Extensions is on, otherwise the whole name).
    /// Returns `nil` to skip the row — no match, or an out-of-range index.
    public func proposedBaseName(for base: String, context: ItemContext) -> String? {
        switch self {
        case let .prepend(text):
            return text + base

        case let .append(text):
            return base + text

        case let .replaceFirst(find, with):
            return TextMatching.replaceLiteral(
                in: base, find: find, with: with, occurrences: .first,
                ignoreCase: context.options.ignoreCase)

        case let .replaceLast(find, with):
            return TextMatching.replaceLiteral(
                in: base, find: find, with: with, occurrences: .last,
                ignoreCase: context.options.ignoreCase)

        case let .replaceAll(find, with):
            return TextMatching.replaceLiteral(
                in: base, find: find, with: with, occurrences: .all,
                ignoreCase: context.options.ignoreCase)

        case let .wildcard(find, with):
            return TextMatching.replaceWildcard(
                in: base, pattern: find, with: with, ignoreCase: context.options.ignoreCase)

        case let .regex(pattern, template):
            return TextMatching.replaceRegex(
                in: base, pattern: pattern, template: template,
                ignoreCase: context.options.ignoreCase)

        case let .removeCharacters(mode):
            return removeCharacters(from: base, mode: mode)

        case let .insertCharacters(text, mode, pad):
            return insertCharacters(into: base, text: text, mode: mode, padToLength: pad)

        case let .changeCase(textCase):
            return textCase.apply(to: base)

        case let .cleanUp(config):
            return Self.cleanUp(base, config: config)

        case let .sequence(config):
            return sequenceName(base: base, config: config, index: context.index)

        case let .date(config):
            return dateName(base: base, config: config, metadata: context.metadata)
        }
    }

    /// Order the items before numbering. Only Sequence reorders; everything
    /// else keeps the table's order.
    public func order(_ items: [FileItem], provider: FileMetadataProvider) -> [FileItem] {
        guard case let .sequence(config) = self, config.sort != .custom else { return items }
        let sorted: [FileItem]
        switch config.sort {
        case .custom:
            return items  // Unreachable: the guard above already returns for .custom.
        case .alphabetical:
            sorted = items.sorted {
                $0.originalName.localizedStandardCompare($1.originalName) == .orderedAscending
            }
        case .fileDate, .exifDate:
            // Read each file's date once, not on every comparison.
            let key: (FileItem) -> Date = { item in
                let metadata = provider.metadata(for: item.url)
                let date = config.sort == .fileDate ? metadata.modificationDate : metadata.exifDate
                return date ?? .distantPast
            }
            // Tie-break on name so files sharing a date (or missing one) keep a
            // stable, run-to-run order rather than numbering arbitrarily.
            sorted = items.map { (item: $0, key: key($0)) }
                .sorted {
                    ($0.key, $0.item.originalName) < ($1.key, $1.item.originalName)
                }
                .map(\.item)
        }
        return config.ascending ? sorted : sorted.reversed()
    }

    // MARK: - Clean Up

    /// Characters removed by Clean Up's "remove illegal" step: those unsafe in
    /// a file name on macOS or Windows, plus control characters.
    private static let illegalCharacters = CharacterSet(charactersIn: #"/\:*?"<>|"#)
        .union(.controlCharacters)

    /// Precompiled once, rather than recompiled on every `cleanUp` call.
    /// `Regex` isn't `Sendable`, but matching against it is read-only and
    /// reentrant, so sharing this immutable value across threads is safe.
    nonisolated(unsafe) private static let whitespaceRun = /\s+/

    /// May empty the name (a base of only illegal characters); the engine
    /// flags an emptied name as invalid, as it does for every function.
    private static func cleanUp(_ base: String, config: CleanUpConfig) -> String {
        var result = base
        if config.collapseWhitespace {
            result = result.replacing(whitespaceRun, with: " ")
            result = result.trimmingCharacters(in: .whitespaces)
        }
        if config.replaceSpaces {
            result = result.replacingOccurrences(of: " ", with: config.spaceReplacement)
        }
        if config.removeDiacritics {
            result = result.folding(
                options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX"))
        }
        if config.removeIllegal {
            result = result.components(separatedBy: illegalCharacters).joined()
        }
        return result
    }

    // MARK: - Remove / Insert

    private func removeCharacters(from base: String, mode: RemoveMode) -> String? {
        let chars = Array(base)
        switch mode {
        case let .range(location, length):
            // A start beyond the name skips the row; an end beyond it clamps.
            // Clamp the count before adding so a huge `length` can't overflow.
            guard location >= 0, location < chars.count, length > 0 else { return nil }
            let end = location + min(length, chars.count - location)
            var result = chars
            result.removeSubrange(location..<end)
            return String(result)
        case let .fromEnd(count):
            guard count > 0 else { return base }
            guard count < chars.count else { return "" }
            return String(chars.dropLast(count))
        }
    }

    private func insertCharacters(
        into base: String, text: String, mode: InsertMode, padToLength: Int?
    ) -> String? {
        var chars = Array(base)
        let position: Int
        switch mode {
        case let .atIndex(index):
            // An index past the name skips the row (matches the original).
            guard index >= 0, index <= chars.count else { return nil }
            position = index
        case .fromEnd:
            position = chars.count
        }
        var insertion = Array(text)
        if let target = padToLength, !insertion.isEmpty {
            // Pad: repeat the text at the insertion point until the name is
            // `target` characters — "7" with "0" at index 0 to 3 is "007". A
            // name already that long is skipped, as the original does.
            let needed = target - chars.count
            guard needed > 0 else { return nil }
            let unit = insertion
            insertion = (0..<needed).map { unit[$0 % unit.count] }
        }
        chars.insert(contentsOf: insertion, at: position)
        return String(chars)
    }

    // MARK: - Sequence / Date

    private func sequenceName(base: String, config: SequenceConfig, index: Int) -> String {
        let number = config.start + index
        let digits = max(1, min(6, config.digits))
        let padded = String(format: "%0\(digits)d", number)
        let token =
            config.namePosition == .before ? config.name + padded : padded + config.name
        switch config.placement {
        case .prepend: return token + base
        case .append: return base + token
        case .replaceAll: return token
        }
    }

    private func dateName(base: String, config: DateConfig, metadata: FileMetadata) -> String? {
        let date: Date?
        switch config.source {
        case let .custom(value): date = value
        case .fileCreated: date = metadata.creationDate
        case .exif: date = metadata.exifDate
        }
        // No date available (e.g. EXIF absent): skip the row.
        guard let date else { return nil }
        let pattern: String
        switch config.format {
        case let .preset(preset): pattern = preset.rawValue
        case let .custom(custom): pattern = custom
        }
        let stamp = DateStamp.string(from: date, pattern: pattern)
        guard !stamp.isEmpty else { return nil }
        switch config.placement {
        case .prepend: return stamp + base
        case .append: return base + stamp
        case .replaceAll: return stamp
        }
    }
}
