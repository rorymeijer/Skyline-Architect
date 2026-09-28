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

struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) { Image(systemName: "xmark.circle.fill") }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Close")
            .accessibilityLabel("Close")
    }
}
