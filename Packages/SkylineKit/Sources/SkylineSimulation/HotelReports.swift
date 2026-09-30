import Foundation
import SkylineCore

/// What the unit inspector shows about a hotel room (0.30). Pure data.
public struct HotelInfo: Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        /// Clean and free; it can be booked between `checkIn` and `lastCheckIn`.
        case vacant
        /// Guests booked for tonight: how many are in the room now, and when they leave.
        case booked(present: Int, guests: Int, checkOut: String)
        /// The last guests have left: a housekeeper must make it up before it can be booked again.
        case awaitingHousekeeping(housekeeperOnTheWay: Bool)
    }

    public var status: Status
    public var sleeps: Int
    /// A night's price at the city's price level.
    public var nightlyRate: Int
    /// "15:00–23:00", and "10:00".
    public var checkIn: String
    public var checkOut: String
    /// Hotel income and nights sold in the whole world so far.
    public var nightsSold: Int
    public var income: Int

    public static func make(room: Room, world: GameWorld, engine: SimulationEngine) -> HotelInfo? {
        guard let spec = engine.rules.hotel(for: room.definitionID) else { return nil }
        let hotel = world.hotel ?? HotelState()
        let status: Status
        if let stay = hotel.stay(in: room.id) {
            let present = stay.guests.filter { id in
                if case let .room(r, _)? = world.people[id]?.place { r == room.id } else { false }
            }.count
            status = .booked(present: present, guests: stay.guests.count, checkOut: SimClock.timeString(stay.checkOut))
        } else if hotel.needsHousekeeping(room.id) {
            let assigned = world.facilities.jobs.contains { $0.room == room.id && $0.kind == .housekeeping && $0.assignee != nil }
            status = .awaitingHousekeeping(housekeeperOnTheWay: assigned)
        } else {
            status = .vacant
        }
        let price = world.city(of: room.buildingID)?.economy.rent ?? 1
        return HotelInfo(status: status, sleeps: spec.guests, nightlyRate: Int((Double(spec.nightlyRate) * price).rounded()),
                         checkIn: "\(spec.checkIn)–\(spec.lastCheckIn)", checkOut: spec.checkOut,
                         nightsSold: hotel.nights, income: hotel.income)
    }
}
