import SwiftUI

/// Gentle hover feedback — macOS button styles give little or none.
/// Inert while the control is disabled.
struct HoverHighlight: ViewModifier {
    var scale: CGFloat = 1.02
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        let active = hovering && isEnabled
        content
            .brightness(active ? 0.07 : 0)
            .scaleEffect(active ? scale : 1)
            .animation(.easeOut(duration: 0.12), value: active)
            .onHover { hovering = $0 }
    }
}

extension View {
    func hoverHighlight(scale: CGFloat = 1.02) -> some View {
        modifier(HoverHighlight(scale: scale))
    }
}
