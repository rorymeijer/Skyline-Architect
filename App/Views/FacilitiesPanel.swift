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
                Text("Facilities").font(.ui(.headline))
                Spacer()
                CloseButton { model.showFacilitiesPanel = false }
            }
            ForEach(s.utilities, id: \.name) { u in
                HStack {
                    Text(u.name).font(.ui(.caption)).scaledFrame(width: 70, alignment: .leading)
                    Text("\(Int(u.supply)) / \(Int(u.demand))").font(.ui(.caption).monospacedDigit())
                    Spacer()
                    Text(u.shortRooms == 0 ? "all supplied" : "\(u.shortRooms) rooms short")
                        .font(.ui(.caption)).foregroundStyle(u.shortRooms == 0 ? Color.green : Color.orange)
                }
            }
            if s.brokenElevators > 0 {
                Text("\(s.brokenElevators) elevator\(s.brokenElevators == 1 ? "" : "s") broken down — a technician repairs it first")
                    .font(.ui(.caption)).foregroundStyle(.red)
            }
            if s.brokenEquipment > 0 {
                Text("\(s.brokenEquipment) equipment room\(s.brokenEquipment == 1 ? "" : "s") out of order — needs a technician")
                    .font(.ui(.caption)).foregroundStyle(.red)
            }
            Divider()
            StaffRow(title: "Janitors", count: s.janitors, open: s.openCleaning, done: s.cleaned) { model.changeStaff(.janitor, by: $0) }
            StaffRow(title: "Technicians", count: s.technicians, open: s.openRepairs, done: s.repaired) { model.changeStaff(.technician, by: $0) }
            if let capacity = s.staffCapacity {
                Text(capacity == 0 ? "No staff room yet — build one to hire staff" : "Staff rooms: \(s.staffCount) of \(capacity) places taken")
                    .font(.ui(.caption)).foregroundStyle(s.staffCount >= capacity ? Color.orange : Color.secondary)
            }
            if s.wastePerDay > 0 {
                Text(String(format: "Waste %.0f kg / day · waste rooms take %.0f kg", s.wastePerDay, s.wasteCapacity))
                    .font(.ui(.caption).monospacedDigit()).foregroundStyle(s.wastePerDay > s.wasteCapacity ? Color.orange : Color.secondary)
            }
            Text("Wages \(Money.format(s.wagesPerDay)) / day · shift 07:00–19:00").font(.ui(.caption).monospacedDigit()).foregroundStyle(.secondary)
            Text(String(format: "Average cleanliness %.0f %% · condition %.0f %%", s.averageCleanliness * 100, s.averageCondition * 100))
                .font(.ui(.caption).monospacedDigit())
            Text(String(format: "Lighting %.1f kW now · %.0f kWh since the last closing", model.lightingKW, model.lightingKWhToday))
                .font(.ui(.caption).monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding(12)
        .scaledFrame(width: 330, alignment: .leading)
        .panelCard()
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
            Text("\(title) \(count)").font(.ui(.caption).weight(.semibold)).scaledFrame(width: 96, alignment: .leading)
            Text("\(open) open · \(done) done").font(.ui(.caption).monospacedDigit()).foregroundStyle(.secondary)
            Spacer()
            PanelButton(title: "−", enabled: count > 0) { change(-1) }
            PanelButton(title: "Hire") { change(1) }
        }
    }
}
