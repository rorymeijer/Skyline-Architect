import SwiftUI
import SkylineSimulation

/// Clock, game speed and population (top center). Space pauses, 1–4 pick a speed.
struct SimulationControls: View {
    let model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            Text(model.clockText)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .frame(minWidth: 118, alignment: .leading)
            HStack(spacing: 2) {
                ForEach(GameSpeed.allCases, id: \.self) { speed in
                    speedButton(speed)
                }
            }
            Rectangle().fill(Color.white.opacity(0.2)).frame(width: 1, height: 18)
            if let w = model.weather {
                HStack(spacing: 5) {
                    Image(systemName: w.symbol).symbolRenderingMode(.multicolor)
                    Text("\(w.name) \(w.temperature)°").font(.system(size: 11, weight: .medium))
                    Image(systemName: "arrow.right").font(.system(size: 8)).foregroundStyle(.secondary)
                    Image(systemName: w.tomorrowSymbol).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                .help("\(w.season): \(w.name), \(w.temperature) °C" + (w.effects.isEmpty ? "" : " — \(w.effects)") + ". Tomorrow: \(w.tomorrowName).")
                Rectangle().fill(Color.white.opacity(0.2)).frame(width: 1, height: 18)
            }
            Label("\(model.population.inRooms + model.population.travelling) in · \(model.population.outside) out",
                  systemImage: "person.2.fill")
                .font(.system(size: 11, weight: .medium))
                .help("People in the building (in rooms or moving) and away. \(model.population.unreachable) cannot reach their room.")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.black.opacity(0.6)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12)))
        .environment(\.colorScheme, .dark)
        .foregroundStyle(.white)
    }

    private func speedButton(_ speed: GameSpeed) -> some View {
        let isOn: Bool = model.speed == speed
        let symbol: String = speed == .paused ? "pause.fill" : "play.fill"
        return Button {
            model.setSpeed(speed)
        } label: {
            HStack(spacing: 2) {
                Image(systemName: symbol).font(.system(size: 9))
                if speed != .paused { Text("\(speed.rawValue)×").font(.system(size: 10, weight: .semibold)) }
            }
            .frame(minWidth: 30, minHeight: 22)
            .background(RoundedRectangle(cornerRadius: 6).fill(isOn ? Color.accentColor : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(speed == .paused ? "Pause (Space)" : "Speed \(speed.label)")
    }
}
