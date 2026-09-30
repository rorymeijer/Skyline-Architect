import SwiftUI
import SkylinePresentation
import SkylineSimulation

/// A hotel room in the unit inspector (0.30): its state tonight, price and times.
struct HotelDetails: View {
    let info: HotelInfo

    var body: some View {
        switch info.status {
        case .vacant:
            Text("Vacant · clean · \(Money.format(info.nightlyRate)) a night").font(.ui(.subheadline).weight(.semibold))
            Text("Booked between \(info.checkIn); guests leave around \(info.checkOut).").font(.ui(.caption)).foregroundStyle(.secondary)
        case let .booked(present, guests, checkOut):
            Text("Booked · \(guests) guest\(guests == 1 ? "" : "s") · \(Money.format(info.nightlyRate))").font(.ui(.subheadline).weight(.semibold))
            Text("\(present) in the room now · check-out around \(checkOut)").font(.ui(.caption)).foregroundStyle(.secondary)
        case let .awaitingHousekeeping(onTheWay):
            Label("Needs housekeeping", systemImage: "sparkles").font(.ui(.subheadline).weight(.semibold)).foregroundStyle(.orange)
            Text(onTheWay ? "A janitor is on the way. Then it can be booked again."
                          : "Hire a janitor (Facilities): the room cannot be booked until it is cleaned.")
                .font(.ui(.caption)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        Text("Sleeps \(info.sleeps) · the hotel has sold \(info.nightsSold) night\(info.nightsSold == 1 ? "" : "s") for \(Money.format(info.income))")
            .font(.ui(.caption2)).foregroundStyle(.secondary)
    }
}
