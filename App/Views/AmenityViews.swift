import SwiftUI
import SkylineCore
import SkylinePresentation
import SkylineSimulation

/// An amenity in the unit inspector (0.22): hours, seats, customers now, and today's and
/// yesterday's customers and takings with the landlord's share.
struct AmenityDetails: View {
    let info: AmenityInfo

    var body: some View {
        Divider()
        HStack {
            Label(info.operated ? (info.isOpenNow ? "Open" : "Closed") : "Closed — no operator",
                  systemImage: info.isOpenNow ? "door.left.hand.open" : "door.left.hand.closed")
                .font(.caption.weight(.semibold))
                .foregroundStyle(info.isOpenNow ? Color.green : Color.secondary)
            Spacer()
            Text("\(info.hours) · \(info.seats) seats").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
        if info.operated {
            Text("\(info.customers) customer\(info.customers == 1 ? "" : "s") inside now").font(.caption)
            let s = info.today
            row("Today", visits: s.visits, street: s.streetVisits, takings: s.takings)
            row("Yesterday", visits: s.lastVisits, street: s.lastStreetVisits, takings: s.lastTakings)
            Text("Your share: \(Int((info.share * 100).rounded())) % of the takings, paid at the 06:00 closing (yesterday \(Money.format(Int((Double(s.lastTakings) * info.share).rounded()))))")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func row(_ title: String, visits: Int, street: Int, takings: Int) -> some View {
        HStack {
            Text(title).font(.caption2).foregroundStyle(.secondary).frame(width: 64, alignment: .leading)
            Text("\(visits) customers · \(street) from the street").font(.caption2.monospacedDigit())
            Spacer()
            Text(Money.format(takings)).font(.caption2.monospacedDigit())
        }
    }
}

/// The building's amenities in the leasing panel (0.22).
struct AmenityTotals: View {
    let summary: AmenitySummary

    var body: some View {
        Divider()
        Text("Amenities").font(.caption.weight(.semibold))
        Text("\(summary.open) of \(summary.venues) open now · \(summary.visitorsNow) visitor\(summary.visitorsNow == 1 ? "" : "s") inside")
            .font(.caption.monospacedDigit())
        Text("Yesterday \(summary.lastVisits) customers (\(summary.lastStreetVisits) from the street) · takings \(Money.format(summary.lastTakings)) · your share \(Money.format(summary.lastShare))")
            .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
