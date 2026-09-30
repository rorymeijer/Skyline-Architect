import Foundation

/// One night in a hotel room (0.30): booked in the afternoon or evening, its guests arrive,
/// sleep and check out in the morning. The room is paid for at checkout.
public struct HotelStay: Codable, Hashable, Sendable {
    public var room: RoomID
    public var guests: [PersonID]
    public var booked: Tick
    /// When the guests leave; the night is paid and the room needs housekeeping then.
    public var checkOut: Tick
    /// What the night costs, at the city's price level when booked.
    public var rate: Int

    public init(room: RoomID, guests: [PersonID], booked: Tick, checkOut: Tick, rate: Int) {
        self.room = room
        self.guests = guests
        self.booked = booked
        self.checkOut = checkOut
        self.rate = rate
    }
}

/// Hotel rooms in use and waiting for housekeeping (0.30, save format 20). A room with a
/// stay is booked; a room in `awaitingHousekeeping` cannot be booked until a janitor has
/// cleaned it after the last guests left.
public struct HotelState: Codable, Hashable, Sendable {
    /// Current stays, in booking order.
    public var stays: [HotelStay] = []
    /// Rooms whose guests have left and that are not cleaned yet (sorted by id).
    public var awaitingHousekeeping: [RoomID] = []
    /// Nights sold and hotel income since the start (for the reports).
    public var nights = 0
    public var income = 0

    public init() {}

    public func stay(in room: RoomID) -> HotelStay? { stays.first { $0.room == room } }
    public func needsHousekeeping(_ room: RoomID) -> Bool { awaitingHousekeeping.contains(room) }
}
