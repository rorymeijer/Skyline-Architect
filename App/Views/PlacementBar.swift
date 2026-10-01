import SwiftUI
import SkylinePresentation

/// Touch placement (0.30): the held ghost's size and price, the buttons to shape it, Cancel
/// and Place. Rooms and floors (0.30.4): either edge grows or shrinks one module, and the
/// arrows move the whole ghost a module or a floor, so it lands exactly where it should.
/// Shafts the same way at their bottom and top; dragging an existing shaft's end keeps
/// Taller / Lower. Taps and drags still move the far end, and two fingers pan.
struct PlacementBar: View {
    let model: AppModel
    let preview: PlacementPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: preview.isValid ? "checkmark.circle.fill" : "xmark.octagon.fill")
                    .foregroundStyle(preview.isValid ? Color.green : Color.red)
                Text(preview.label).font(.ui(.caption).monospacedDigit()).lineLimit(2)
            }
            HStack(spacing: 10) {
                if !preview.isDemolition {
                    if let axis = model.heldEditAxis {
                        edgeEdits(axis)
                    } else {
                        // Only left for dragging an existing shaft's end: it moves that one end.
                        PanelButton(title: "Lower") { model.nudgeHeldPlacement(by: -1) }.accessibilityLabel("One floor fewer")
                        PanelButton(title: "Taller") { model.nudgeHeldPlacement(by: 1) }.accessibilityLabel("One floor more")
                    }
                }
                PanelButton(title: "Cancel") { model.cancelHeldPlacement() }
                PanelButton(title: preview.isDemolition ? "Demolish" : "Place", enabled: preview.isValid) { model.confirmHeldPlacement() }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.7)))
        .environment(\.colorScheme, .dark)
    }

    /// One end (out, in), the whole ghost (left, up, down, right), the other end (in, out):
    /// left and right for rooms and floors, bottom and top for shafts.
    @ViewBuilder private func edgeEdits(_ axis: PlacementPlanner.EditAxis) -> some View {
        let sideways = axis == .sideways
        EditGroup(title: sideways ? "Left" : "Bottom") {
            edit(sideways ? .left(1) : .bottom(1), "plus", sideways ? "Longer on the left" : "One floor more at the bottom")
            edit(sideways ? .left(-1) : .bottom(-1), "minus", sideways ? "Shorter on the left" : "One floor less at the bottom")
        }
        EditGroup(title: "Move") {
            edit(.move(columns: -1, floors: 0), "arrowtriangle.left.fill", "Move left")
            edit(.move(columns: 0, floors: 1), "arrowtriangle.up.fill", "Move up a floor")
            edit(.move(columns: 0, floors: -1), "arrowtriangle.down.fill", "Move down a floor")
            edit(.move(columns: 1, floors: 0), "arrowtriangle.right.fill", "Move right")
        }
        EditGroup(title: sideways ? "Right" : "Top") {
            edit(sideways ? .right(-1) : .top(-1), "minus", sideways ? "Shorter on the right" : "One floor less at the top")
            edit(sideways ? .right(1) : .top(1), "plus", sideways ? "Longer on the right" : "One floor more at the top")
        }
    }

    private func edit(_ edit: HeldEdit, _ symbol: String, _ label: String) -> some View {
        IconButton(symbol: symbol, label: label, enabled: model.canEditHeldPlacement(edit)) { model.editHeldPlacement(edit) }
    }
}

/// A captioned row of small buttons in the placement bar.
private struct EditGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) { content }
            Text(title).font(.ui(.caption2)).foregroundStyle(.secondary)
        }
    }
}

/// A square icon button, big enough for a finger.
private struct IconButton: View {
    let symbol: String
    let label: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
                .frame(width: 32, height: 28)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(enabled ? 0.15 : 0.05)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(label)
    }
}
