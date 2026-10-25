import SwiftUI

/// Renders a proposed name with the part that changed picked out, so the eye
/// lands on the edit rather than re-reading the whole name. The shared leading
/// and trailing text is drawn muted; the inserted or replaced middle is drawn
/// in the accent colour.
enum NameDiff {
    /// `onSelection`: the row is selected, so its background is the accent
    /// colour. The colours go, leaving the selection's own text colour, and
    /// the change is picked out by weight alone.
    static func attributed(original: String, proposed: String, onSelection: Bool = false) -> AttributedString
    {
        let old = Array(original)
        let new = Array(proposed)

        var prefix = 0
        while prefix < old.count, prefix < new.count, old[prefix] == new[prefix] {
            prefix += 1
        }
        var suffix = 0
        while suffix < (old.count - prefix), suffix < (new.count - prefix),
            old[old.count - 1 - suffix] == new[new.count - 1 - suffix]
        {
            suffix += 1
        }

        let head = String(new[0..<prefix])
        let middle = String(new[prefix..<(new.count - suffix)])
        let tail = String(new[(new.count - suffix)...])

        var result = AttributedString()
        result += styled(head, color: onSelection ? nil : .secondary)
        result += styled(middle, color: onSelection ? nil : .accentColor, bold: true)
        result += styled(tail, color: onSelection ? nil : .secondary)
        return result
    }

    private static func styled(
        _ string: String, color: Color?, bold: Bool = false
    ) -> AttributedString {
        guard !string.isEmpty else { return AttributedString() }
        var piece = AttributedString(string)
        if let color { piece.foregroundColor = color }
        if bold { piece.font = .body.bold() }
        return piece
    }
}

/// A New Name cell's diff, which knows whether its row is selected: a selected
/// table row raises the background prominence for what it holds.
/// /documentation/swiftui/environmentvalues/backgroundprominence
struct NameDiffText: View {
    let original: String
    let proposed: String
    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        Text(
            NameDiff.attributed(original: original, proposed: proposed, onSelection: prominence == .increased)
        )
    }
}
