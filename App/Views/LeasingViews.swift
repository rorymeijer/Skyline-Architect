import SwiftUI
import SkylineCore
import SkylinePresentation
import SkylineSimulation

/// Unit inspector (click a room): tenant and their view of the unit, or — for a vacant
/// unit — how each kind of tenant rates it and what happened on the market.
struct UnitInspector: View {
    let report: UnitReport
    var shaftOptions: [ShaftResizeOption] = []
    var onResize: (BuildCommand) -> Void = { _ in }
    /// Offer the (vacant) unit for sale (true) or for rent (false).
    var onTenure: (Bool) -> Void = { _ in }
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(report.title).font(.headline)
                Text("\(report.floor) · \(report.width) m").font(.caption).foregroundStyle(.secondary)
                Spacer()
                CloseButton(action: onClose)
            }
            if let o = report.occupant {
                Text(o.name).font(.subheadline.weight(.semibold))
                Text("\(o.typeName) · \(o.members) \(o.members == 1 ? "person" : "people") · \(o.present) here now")
                    .font(.caption).foregroundStyle(.secondary)
                if let price = o.purchasePrice {
                    Text("Owner since day \(o.sinceDay) · " + (price > 0 ? "bought for \(Money.format(price))" : "bought from the previous owner"))
                        .font(.caption.monospacedDigit())
                    Text("Service charges \(Money.format(o.rent)) / month").font(.caption.monospacedDigit())
                } else {
                    Text("Rent \(Money.format(o.rent)) / month · since day \(o.sinceDay)").font(.caption.monospacedDigit())
                }
                Meter(label: "Satisfaction", value: o.satisfaction)
                if o.unhappyDays > 0 {
                    Text("Unhappy for \(o.unhappyDays) day\(o.unhappyDays == 1 ? "" : "s") — leaves at \(o.leavesAfter)").font(.caption).foregroundStyle(.orange)
                }
                if let a = o.appraisal { Criteria(appraisal: a) }
            } else if report.leasable {
                TenureRow(report: report, onTenure: onTenure)
                ForEach(report.interest, id: \.typeName) { i in
                    HStack {
                        Image(systemName: i.wouldSign ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundStyle(i.wouldSign ? Color.green : Color.secondary)
                        Text(i.typeName).font(.caption)
                        Spacer()
                        Text(i.wouldSign ? String(format: "%.0f%%", i.appraisal.total * 100)
                                         : LeasingSummary.describe(i.appraisal.weakest))
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
                if let best = report.interest.first { Criteria(appraisal: best.appraisal) }
            } else {
                Text("Not rentable — shared space or services.").font(.caption).foregroundStyle(.secondary)
            }
            if !report.utilities.isEmpty {
                Divider()
                HStack(spacing: 8) {
                    ForEach(report.utilities, id: \.name) { u in
                        Label(u.name, systemImage: u.served >= 0.99 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.caption2).foregroundStyle(u.served >= 0.99 ? Color.green : Color.orange)
                    }
                }
                Meter(label: "Cleanliness", value: report.cleanliness)
                Meter(label: "Condition", value: report.condition)
            }
            if !shaftOptions.isEmpty { ShaftHeightControls(options: shaftOptions, onResize: onResize) }
            if !report.history.isEmpty {
                Divider()
                ForEach(Array(report.history.prefix(4).enumerated()), id: \.offset) { _, e in
                    Text("D\(SimClock.day(e.tick) + 1) \(SimClock.timeString(e.tick)) · \(e.typeID) \(e.outcome.rawValue)"
                         + (e.reason.map { ": " + LeasingSummary.describe($0) } ?? ""))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(width: 300, alignment: .leading)
        .panelCard()
        .environment(\.colorScheme, .dark)
    }
}

/// Occupancy, rent roll and the market's recent activity (⌥⌘L).
struct LeasingPanel: View {
    let summary: LeasingSummary
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Leasing").font(.headline)
                Spacer()
                CloseButton(action: onClose)
            }
            Text("\(summary.leased) of \(summary.units) units let · \(summary.households) households · \(summary.businesses) businesses")
                .font(.caption)
            if summary.owned + summary.forSale > 0 {
                Text("\(summary.owned) flat\(summary.owned == 1 ? "" : "s") sold · \(summary.forSale) for sale").font(.caption)
            }
            Text("Rent roll \(Money.format(summary.rentRoll)) / month (charged from Phase 9)").font(.caption.monospacedDigit())
            Meter(label: "Avg satisfaction", value: summary.averageSatisfaction)
            let m = summary.market
            Text("Prospects \(m.prospects) · signed \(m.signed) · moved out \(m.movedOut)").font(.caption.monospacedDigit())
            Text(DeclineReason.allCases.map { "\(LeasingSummary.describe($0)) \(m.declines($0))" }.joined(separator: " · "))
                .font(.caption2).foregroundStyle(.secondary)
            Divider()
            ForEach(Array(summary.recent.enumerated()), id: \.offset) { _, line in
                Text(line).font(.caption2.monospacedDigit()).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(12)
        .frame(width: 330, alignment: .leading)
        .panelCard()
        .environment(\.colorScheme, .dark)
    }
}

private struct Criteria: View {
    let appraisal: UnitAppraisal

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Meter(label: "Rent", value: appraisal.rent)
            Meter(label: appraisal.accessSeconds.isFinite ? "Access \(Int(appraisal.accessSeconds)) s" : "Access —", value: appraisal.access)
            Meter(label: "Quiet", value: appraisal.noise)
            Meter(label: "View", value: appraisal.view)
            Meter(label: "Services", value: appraisal.services)
        }
    }
}

/// A small horizontal bar (SwiftUI-drawn, so captures render it).
private struct Meter: View {
    let label: String
    let value: Double

    var body: some View {
        HStack(spacing: 6) {
            Text(label).font(.caption2).foregroundStyle(.secondary).frame(width: 96, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule().fill(value >= 0.6 ? Color.green : value >= 0.4 ? Color.orange : Color.red)
                        .frame(width: max(g.size.width * min(max(value, 0), 1), 2))
                }
            }
            .frame(height: 6)
        }
        .frame(height: 12)
    }
}

/// Height controls of a selected shaft (0.20.2): one floor up or down at either end, the
/// same as dragging the shaft's end with its tool. Disabled options say why.
private struct ShaftHeightControls: View {
    let options: [ShaftResizeOption]
    let onResize: (BuildCommand) -> Void

    var body: some View {
        Divider()
        Text("Height").font(.caption.weight(.semibold))
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 6) {
            ForEach(options) { o in
                Button { if let c = o.command { onResize(c) } } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Label(o.title, systemImage: o.symbol).font(.caption.weight(.semibold))
                        Text(o.detail).font(.caption2.monospacedDigit()).foregroundStyle(.secondary).lineLimit(1)
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(o.command == nil ? 0.04 : 0.12)))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(o.command == nil)
                .opacity(o.command == nil ? 0.55 : 1)
                .help(o.detail)
                .accessibilityLabel(o.title)
                .accessibilityValue(o.detail)
            }
        }
        Text("Or drag the shaft's top or bottom with its tool.").font(.caption2).foregroundStyle(.secondary)
    }
}

/// A vacant unit: rented out, or offered for sale, with a switch between the two (0.20.3).
/// A sold flat that stands empty is on the resale market between private parties.
private struct TenureRow: View {
    let report: UnitReport
    let onTenure: (Bool) -> Void

    var body: some View {
        switch report.tenure {
        case .owned:
            Text("Privately owned · for resale by its owner").font(.subheadline.weight(.semibold))
            Text("Service charges \(Money.format(report.serviceCharge ?? 0)) / month once a buyer moves in").font(.caption).foregroundStyle(.secondary)
        case .forSale:
            Text("For sale · \(Money.format(report.salePrice ?? 0))").font(.subheadline.weight(.semibold))
            Text("Then \(Money.format(report.serviceCharge ?? 0)) / month service charges").font(.caption).foregroundStyle(.secondary)
            PanelButton(title: "Rent Out Instead") { onTenure(false) }
        case .rent:
            Text("Vacant · asking \(Money.format(report.askingRent ?? 0)) / month").font(.subheadline.weight(.semibold))
            if report.canBeSold, let price = report.salePrice {
                PanelButton(title: "Offer for Sale · \(Money.format(price))") { onTenure(true) }
                    .help("Sold once for this price; the owner then pays \(Money.format(report.serviceCharge ?? 0)) / month service charges.")
            }
        }
    }
}
