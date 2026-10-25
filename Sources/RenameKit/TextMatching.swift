import Foundation

/// Literal, wildcard and regular-expression matching for the replace
/// functions. Each returns `nil` when there is no match, so the engine can
/// skip the row rather than rename it to itself.
///
/// Replacement uses `NSRegularExpression`: it is the Foundation API built for
/// first-match range replacement and `$1` template back-references, which the
/// `Regex` value type does not express directly.
enum TextMatching {
    enum Occurrences {
        case first
        case last
        case all
    }

    static func replaceLiteral(
        in base: String, find: String, with replacement: String,
        occurrences: Occurrences, ignoreCase: Bool
    ) -> String? {
        guard !find.isEmpty else { return nil }
        var options: String.CompareOptions = []
        if ignoreCase { options.insert(.caseInsensitive) }

        switch occurrences {
        case .first:
            guard let range = base.range(of: find, options: options) else { return nil }
            return base.replacingCharacters(in: range, with: replacement)
        case .last:
            guard let range = base.range(of: find, options: options.union(.backwards))
            else { return nil }
            return base.replacingCharacters(in: range, with: replacement)
        case .all:
            guard base.range(of: find, options: options) != nil else { return nil }
            return base.replacingOccurrences(of: find, with: replacement, options: options)
        }
    }

    static func replaceWildcard(
        in base: String, pattern: String, with replacement: String, ignoreCase: Bool
    ) -> String? {
        guard !pattern.isEmpty else { return nil }
        let regexPattern = wildcardToRegex(pattern)
        // The replacement is literal here (wildcards have no capture groups),
        // so escape any `$` so it is not read as a back-reference.
        let template = NSRegularExpression.escapedTemplate(for: replacement)
        return replaceFirstMatch(
            in: base, pattern: regexPattern, template: template, ignoreCase: ignoreCase)
    }

    static func replaceRegex(
        in base: String, pattern: String, template: String, ignoreCase: Bool
    ) -> String? {
        guard !pattern.isEmpty else { return nil }
        return replaceFirstMatch(
            in: base, pattern: pattern, template: template, ignoreCase: ignoreCase)
    }

    // MARK: - Private

    /// Translate `*` (any run) and `?` (one character) to a regex, escaping
    /// every other metacharacter so it matches literally.
    private static func wildcardToRegex(_ pattern: String) -> String {
        var out = ""
        for ch in pattern {
            switch ch {
            case "*": out += ".*"
            case "?": out += "."
            default: out += NSRegularExpression.escapedPattern(for: String(ch))
            }
        }
        return out
    }

    /// Compiled patterns, keyed by options and pattern. A plan runs the same
    /// pattern for every row on every keystroke, so compile each one once.
    /// `NSCache` is thread-safe and `NSRegularExpression` immutable, so
    /// sharing them across threads is safe.
    nonisolated(unsafe) private static let compiled = NSCache<NSString, NSRegularExpression>()

    private static func compiledRegex(
        _ pattern: String, options: NSRegularExpression.Options
    ) -> NSRegularExpression? {
        let key = "\(options.rawValue)|\(pattern)" as NSString
        if let cached = compiled.object(forKey: key) { return cached }
        // An invalid pattern matches nothing: skip the row rather than throw.
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return nil
        }
        compiled.setObject(regex, forKey: key)
        return regex
    }

    private static func replaceFirstMatch(
        in base: String, pattern: String, template: String, ignoreCase: Bool
    ) -> String? {
        var options: NSRegularExpression.Options = []
        if ignoreCase { options.insert(.caseInsensitive) }
        guard let regex = compiledRegex(pattern, options: options) else { return nil }
        let ns = base as NSString
        let full = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: base, range: full) else { return nil }
        let replacement = regex.replacementString(for: match, in: base, offset: 0, template: template)
        return ns.replacingCharacters(in: match.range, with: replacement)
    }
}

/// Formats a date for the Date rename. The POSIX locale keeps a given pattern's
/// text stable regardless of the user's region (type a pattern for localized
/// month names). The local time zone is used so the stamp matches the calendar
/// day the user sees in Finder — a custom date picked as "Jan 1", a file's
/// created/modified day, or a photo's EXIF capture day — rather than shifting
/// across midnight into UTC. (`SystemFileMetadataProvider` parses EXIF
/// wall-clock strings in the same local zone, so capture dates round-trip.)
enum DateStamp {
    /// One formatter per pattern, reused for every row rather than built per
    /// call. `DateFormatter` is thread-safe for formatting and `NSCache` for
    /// access, so sharing them is safe.
    nonisolated(unsafe) private static let formatters = NSCache<NSString, DateFormatter>()

    static func string(from date: Date, pattern: String) -> String {
        formatter(for: pattern).string(from: date)
    }

    private static func formatter(for pattern: String) -> DateFormatter {
        if let cached = formatters.object(forKey: pattern as NSString) { return cached }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // Autoupdating, so a cached formatter follows a time-zone change.
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = pattern
        formatters.setObject(formatter, forKey: pattern as NSString)
        return formatter
    }
}
