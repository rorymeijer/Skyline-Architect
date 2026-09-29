import SwiftUI

/// Shared look of the side panels and banners (Phase 20): one material card with a hairline
/// edge (it reads against both sky and cut-away), and a close button VoiceOver can name.
extension View {
    func panelCard(cornerRadius: CGFloat = 12) -> some View {
        background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(Color.white.opacity(0.1)))
            .accessibilityElement(children: .contain)
    }
}

/// A ring around a control while it has keyboard focus (F4): Tab moves between controls
/// when Keyboard navigation (Mac) or Full Keyboard Access (iPad) is on. The custom button
/// styles draw no focus effect of their own.
private struct FocusRing: ViewModifier {
    @Environment(\.isFocused) private var focused
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content.overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(Color.accentColor, lineWidth: 2).opacity(focused ? 1 : 0))
    }
}

extension View {
    func focusRing(cornerRadius: CGFloat = 8) -> some View { modifier(FocusRing(cornerRadius: cornerRadius)) }
}

struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) { Image(systemName: "xmark.circle.fill").focusRing(cornerRadius: 9) }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Close")
            .accessibilityLabel("Close")
    }
}
