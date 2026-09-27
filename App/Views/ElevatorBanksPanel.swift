import SwiftUI
import SkylineCore
import SkylineSimulation

/// Elevator banks of the active property (⌥⌘E): strategy per bank and live statistics.
/// Changing the strategy is a player setting forwarded to the model (not construction).
struct ElevatorBanksPanel: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Elevator Banks").font(.headline)
                Spacer()
                Button { model.showBanksPanel = false } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            if model.banks.isEmpty {
                Text("No elevators yet. Place elevator shafts side by side to form a bank.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(model.banks) { bank in
                BankRow(bank: bank) { model.setStrategy($0, bank: bank.id) }
            }
        }
        .padding(12)
        .frame(width: 330, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .environment(\.colorScheme, .dark)
    }
}

private struct BankRow: View {
    let bank: ElevatorTraffic.Bank
    let onStrategy: (DispatchStrategy) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("Bank \(bank.name)").font(.subheadline.weight(.semibold))
                Text("\(bank.floors) · \(bank.cars) car\(bank.cars == 1 ? "" : "s")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            // SwiftUI-drawn segments (AppKit pickers render as placeholders in captures).
            HStack(spacing: 2) {
                ForEach(DispatchStrategy.allCases, id: \.self) { strategy in
                    Button { onStrategy(strategy) } label: {
                        Text(strategy.rawValue.capitalized)
                            .font(.caption.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 6)
                                .fill(strategy == bank.strategy ? Color.accentColor : Color.white.opacity(0.08)))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .disabled(bank.cars < 2)
            .opacity(bank.cars < 2 ? 0.5 : 1)
            let s = bank.stats
            Text("Avg wait \(Int(s.averageWait.rounded())) s · max \(s.maxWait) s · \(bank.passengersLastHour) pax last hour")
                .font(.caption.monospacedDigit())
            Text("\(s.boardings) boardings · \(s.stops) stops · \(s.abandoned) took the stairs · \(bank.waitingNow) waiting")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }
}
