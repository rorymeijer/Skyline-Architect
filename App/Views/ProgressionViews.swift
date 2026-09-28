import SwiftUI
import SkylineCore
import SkylineSimulation

/// Building class, reputation and the way to the next class (⌥⌘P).
struct ProgressPanel: View {
    let model: AppModel

    var body: some View {
        let s = model.progression
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Standing").font(.headline)
                Spacer()
                Button { model.showProgressPanel = false } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(s.className).font(.title3.weight(.bold))
                Spacer()
                Text(String(format: "Reputation %.0f", s.reputation)).font(.callout.monospacedDigit())
            }
            ProgressBar(value: s.reputation / 100, tint: s.reputation >= 55 ? .green : s.reputation >= 35 ? .yellow : .orange)
            if let a = s.assessment {
                Text(String(format: "Today %.0f — satisfaction %.0f %% · services %.0f %% · waits %.0f %% · occupancy %.0f %%",
                            a.target, a.satisfaction * 100, a.services * 100, a.waits * 100, a.occupancy * 100))
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Text(s.byClass ? (s.maxFloor.map { "Standard game · building up to floor \($0)" } ?? "Standard game · no height limit")
                           : "Sandbox · everything unlocked")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            if let next = s.nextClassName {
                Text("Next: \(next)").font(.caption.weight(.semibold))
                ForEach(s.requirements, id: \.label) { r in
                    HStack(spacing: 6) {
                        Image(systemName: r.met ? "checkmark.circle.fill" : "circle").foregroundStyle(r.met ? Color.green : Color.secondary)
                        Text(r.label).font(.caption)
                        Spacer()
                        Text(r.needed == 1 && r.label != "Population" && r.label != "Reputation" ? (r.met ? "built" : "needed")
                                                                                                : "\(Int(r.current)) / \(Int(r.needed))")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
                if !s.nextUnlocks.isEmpty {
                    Text("Unlocks: " + s.nextUnlocks.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("Highest class reached.").font(.caption)
            }
        }
        .padding(12)
        .frame(width: 330, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .environment(\.colorScheme, .dark)
    }
}

private struct ProgressBar: View {
    let value: Double
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.15))
                Capsule().fill(tint).frame(width: geo.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 6)
    }
}

/// Shown after a promotion until dismissed.
struct PromotionBanner: View {
    let text: String
    let close: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "rosette").font(.title2).foregroundStyle(.yellow)
            Text(text).font(.callout.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
            Button(action: close) { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 520)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.yellow.opacity(0.5)))
        .environment(\.colorScheme, .dark)
    }
}
