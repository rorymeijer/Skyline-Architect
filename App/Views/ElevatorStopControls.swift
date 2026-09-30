import SwiftUI

/// The floors of a selected elevator (0.30), top floor first: tap a floor to switch its
/// stop off or on, as on the classic tower games' elevator panels. The car passes a switched-
/// off floor; at least two floors always stay on.
struct ElevatorStopControls: View {
    let stops: [ElevatorStopToggle]
    let onToggle: (Int, Bool) -> Void

    var body: some View {
        Divider()
        HStack {
            Text("Stops").font(.ui(.caption).weight(.semibold))
            Spacer()
            Text("\(stops.filter(\.served).count) of \(stops.count) floors").font(.ui(.caption2).monospacedDigit()).foregroundStyle(.secondary)
        }
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 6), spacing: 4) {
            ForEach(stops) { stop in
                Button { onToggle(stop.floor, !stop.served) } label: {
                    Text(stop.label)
                        .font(.ui(.caption).weight(.semibold).monospacedDigit())
                        .frame(maxWidth: .infinity, minHeight: 26)
                        .background(RoundedRectangle(cornerRadius: 6).fill(stop.served ? Color.accentColor.opacity(0.55) : Color.white.opacity(0.06)))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(stop.served ? 0 : 0.2)))
                        .foregroundStyle(stop.served ? Color.primary : Color.secondary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!stop.canToggle)
                .opacity(stop.canToggle ? 1 : 0.6)
                .accessibilityLabel("Floor \(stop.label)")
                .accessibilityValue(stop.served ? "stops" : "passes")
                .help(stop.served ? "Stops here — tap to pass this floor" : "Passes — tap to stop here")
            }
        }
        Text("Tap a floor to switch its stop off or on.").font(.ui(.caption2)).foregroundStyle(.secondary)
    }
}
