import RenameKit

/// The rename functions as a flat, selectable list for the picker. The model
/// keeps editable parameters per kind and assembles the matching
/// `RenameFunction` value from them.
public enum FunctionKind: String, CaseIterable, Identifiable, Sendable {
    case prepend
    case append
    case replaceFirst
    case replaceLast
    case replaceAll
    case wildcard
    case regex
    case removeCharacters
    case insertCharacters
    case changeCase
    case cleanUp
    case sequence
    case date

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .prepend: return "Prepend"
        case .append: return "Append"
        case .replaceFirst: return "Replace First Occurrence"
        case .replaceLast: return "Replace Last Occurrence"
        case .replaceAll: return "Replace All Occurrences"
        case .wildcard: return "Wildcard"
        case .regex: return "Regular Expression"
        case .removeCharacters: return "Remove Characters"
        case .insertCharacters: return "Insert Characters"
        case .changeCase: return "Change Case"
        case .cleanUp: return "Clean Up"
        case .sequence: return "Sequence"
        case .date: return "Date"
        }
    }
}
