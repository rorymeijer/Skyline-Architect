import SwiftUI
import SkylineSimulation

/// Fires in progress and the incident log (⌥⌘I).
struct IncidentsPanel: View {
    let model: AppModel

    var body: some View {
        let s = model.incidents
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Incidents").font(.ui(.headline))
                Spacer()
                CloseButton { model.showIncidentsPanel = false }
            }
            if s.fires.isEmpty {
                Text("No fire in progress.").font(.ui(.caption)).foregroundStyle(.secondary)
            }
            ForEach(s.fires, id: \.incident) { f in
                VStack(alignment: .leading, spacing: 2) {
                    Text(f.detail).font(.ui(.caption).weight(.semibold)).foregroundStyle(.orange)
                    Text("\(f.minutes) min · \(f.burningRooms) burning · " + (f.brigadeInMinutes > 0 ? "brigade in \(f.brigadeInMinutes) min" : "brigade on site"))
                        .font(.ui(.caption).monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            Divider()
            if s.recent.isEmpty {
                Text("Nothing has happened yet.").font(.ui(.caption)).foregroundStyle(.secondary)
            }
            ForEach(s.recent, id: \.id) { e in
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: e.kind == "fire" ? "flame" : "exclamationmark.triangle")
                        .foregroundStyle(e.kind == "fire" ? Color.orange : Color.yellow).font(.ui(.caption))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(e.detail).font(.ui(.caption)).fixedSize(horizontal: false, vertical: true)
                        Text(e.when + (e.ongoing ? " · ongoing" : "")).font(.ui(.caption2).monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .scaledFrame(width: 330, alignment: .leading)
        .panelCard()
        .environment(\.colorScheme, .dark)
    }
}

/// Alert for a fire in progress or a new incident, with a button to look at it.
struct IncidentBanner: View {
    let text: String
    let fire: Bool
    let show: () -> Void
    let close: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(text).font(.ui(.callout).weight(.semibold)).fixedSize(horizontal: false, vertical: true)
            Button("Show", action: show).buttonStyle(.plain).font(.ui(.callout).weight(.bold)).foregroundStyle(fire ? .orange : .yellow)
            CloseButton(action: close)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 560)
        .panelCard()
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder((fire ? Color.orange : Color.yellow).opacity(0.6)))
        .environment(\.colorScheme, .dark)
    }
}
