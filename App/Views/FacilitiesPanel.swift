import SwiftUI
import SkylineCore
import SkylinePresentation
import SkylineSimulation

/// Utilities supply against demand, staff and their work (⌥⌘F).
struct FacilitiesPanel: View {
    let model: AppModel

    var body: some View {
        let s = model.facilities
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Facilities").font(.headline)
                Spacer()
                Button { model.showFacilitiesPanel = false } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }
            ForEach(s.utilities, id: \.name) { u in
                HStack {
                    Text(u.name).font(.caption).frame(width: 70, alignment: .leading)
                    Text("\(Int(u.supply)) / \(Int(u.demand))").font(.caption.monospacedDigit())
                    Spacer()
                    Text(u.shortRooms == 0 ? "all supplied" : "\(u.shortRooms) rooms short")
                        .font(.caption).foregroundStyle(u.shortRooms == 0 ? Color.green : Color.orange)
                }
            }
            if s.brokenEquipment > 0 {
                Text("\(s.brokenEquipment) equipment room\(s.brokenEquipment == 1 ? "" : "s") out of order — needs a technician")
                    .font(.caption).foregroundStyle(.red)
            }
            Divider()
            StaffRow(title: "Janitors", count: s.janitors, open: s.openCleaning, done: s.cleaned) { model.changeStaff(.janitor, by: $0) }
            StaffRow(title: "Technicians", count: s.technicians, open: s.openRepairs, done: s.repaired) { model.changeStaff(.technician, by: $0) }
            Text("Wages \(Money.format(s.wagesPerDay)) / day · shift 07:00–19:00").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            Text(String(format: "Average cleanliness %.0f %% · condition %.0f %%", s.averageCleanliness * 100, s.averageCondition * 100))
                .font(.caption.monospacedDigit())
            Text(String(format: "Lighting %.1f kW now · %.0f kWh since the last closing", model.lightingKW, model.lightingKWhToday))
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 330, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .environment(\.colorScheme, .dark)
    }
}

private struct StaffRow: View {
    let title: String
    let count: Int
    let open: Int
    let done: Int
    let change: (Int) -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text("\(title) \(count)").font(.caption.weight(.semibold)).frame(width: 96, alignment: .leading)
            Text("\(open) open · \(done) done").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            Spacer()
            PanelButton(title: "−", enabled: count > 0) { change(-1) }
            PanelButton(title: "Hire") { change(1) }
        }
    }
}
