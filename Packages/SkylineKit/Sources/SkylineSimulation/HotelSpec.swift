import Foundation
import SkylineCore

/// What a hotel room offers (0.30, `hotels.json`, keyed by room): how many guests it sleeps,
/// what a night costs, when guests check in and out, and how likely a vacant, clean room is
/// to be booked on a given night. The room itself is a room type without `rentPerModule`:
/// it is not leased to a tenant but sold night by night.
public struct HotelSpec: Codable, Hashable, Sendable {
    /// Room definition id.
    public var room: String
    public var guests: Int
    /// A night's price, before the city's price level.
    public var nightlyRate: Int
    /// Bookings are made from `checkIn` until `lastCheckIn` ("HH:MM"); guests arrive within the
    /// hour of their booking.
    public var checkIn: String
    public var lastCheckIn: String
    /// Guests leave around this time the next morning (±45 minutes).
    public var checkOut: String
    /// Chance (0…1) that a vacant, clean, fully served room is booked on a night, before the
    /// city's demand, the weather and the building's reputation.
    public var bookingChance: Double

    public init(room: String, guests: Int, nightlyRate: Int, checkIn: String, lastCheckIn: String, checkOut: String, bookingChance: Double) {
        self.room = room
        self.guests = guests
        self.nightlyRate = nightlyRate
        self.checkIn = checkIn
        self.lastCheckIn = lastCheckIn
        self.checkOut = checkOut
        self.bookingChance = bookingChance
    }

    private static func second(_ hhmm: String) -> Tick? {
        Schedule.Event(at: hhmm, jitterMinutes: 0, goal: .home).secondOfDay
    }

    /// Seconds since midnight: first and last booking hour, checkout.
    public var times: (checkIn: Tick, lastCheckIn: Tick, checkOut: Tick)? {
        guard let a = Self.second(checkIn), let b = Self.second(lastCheckIn), let c = Self.second(checkOut), a <= b, c < a else { return nil }
        return (a, b, c)
    }

    /// Booking hours per night (at least one).
    public var bookingHours: Int {
        guard let t = times else { return 1 }
        return max(1, Int((t.lastCheckIn - t.checkIn) / 3600) + 1)
    }

    /// Validation problems against the known rooms (empty if valid).
    public func problems(rooms: [RoomSpec]) -> [String] {
        var p: [String] = []
        let name = "hotel '\(room)'"
        if let spec = rooms.first(where: { $0.id == room }) {
            if spec.kind != .room || spec.rentPerModule != nil { p.append("\(name): needs a room without rentPerModule (nights are sold, not leased)") }
        } else {
            p.append("\(name): unknown room")
        }
        if !(1...8).contains(guests) { p.append("\(name): guests must be 1…8") }
        if nightlyRate < 0 { p.append("\(name): nightlyRate must be ≥ 0") }
        if times == nil { p.append("\(name): checkOut must come before checkIn, and checkIn not after lastCheckIn (HH:MM)") }
        if !(0...1).contains(bookingChance) { p.append("\(name): bookingChance must be 0…1") }
        return p
    }
}
