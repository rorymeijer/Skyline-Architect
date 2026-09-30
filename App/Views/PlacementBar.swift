import SwiftUI
import SkylinePresentation

/// Touch placement (0.30): the held ghost's size and price, ± one module, Cancel and Place.
/// Tap elsewhere to move the far end, drag from the end to stretch it, or pan with two
/// fingers to reach further first.
struct PlacementBar: View {
    let model: AppModel
    let preview: PlacementPreview

    var body: some View {
        let vertical = model.heldGrowsVertically
        HStack(spacing: 8) {
            Image(systemName: preview.isValid ? "checkmark.circle.fill" : "xmark.octagon.fill")
                .foregroundStyle(preview.isValid ? Color.green : Color.red)
            Text(preview.label).font(.ui(.caption).monospacedDigit()).lineLimit(2).frame(maxWidth: 260, alignment: .leading)
            if !preview.isDemolition {
                PanelButton(title: vertical ? "Lower" : "Shorter") { model.nudgeHeldPlacement(by: -1) }
                    .accessibilityLabel(vertical ? "One floor fewer" : "One module shorter")
                PanelButton(title: vertical ? "Taller" : "Longer") { model.nudgeHeldPlacement(by: 1) }
                    .accessibilityLabel(vertical ? "One floor more" : "One module longer")
            }
            PanelButton(title: "Cancel") { model.cancelHeldPlacement() }
            PanelButton(title: preview.isDemolition ? "Demolish" : "Place", enabled: preview.isValid) { model.confirmHeldPlacement() }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.black.opacity(0.7)))
        .environment(\.colorScheme, .dark)
    }
}
