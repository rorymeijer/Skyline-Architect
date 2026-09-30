import Foundation
import Testing
import SkylineCore
import SkylineContent
@testable import SkylineSimulation

/// Hotel rooms (0.30): booked in the evening, slept in, paid at checkout, then housekept.
@Suite struct HotelTests {
    /// The demo tower with a new top floor of hotel rooms, reached by the elevator.
    func hotelFixture(staff: [PersonRole]) throws -> (SimFixture, [RoomID]) {
        var f = try SimFixture()
        let construction = ConstructionEngine(catalog: f.library.buildCatalog)
        let b = try #require(f.world.buildings[f.building])
        let top = try #require(b.floors.map(\.level).max())
        let roof = try #require(b.plate(at: top))
        try construction.apply(.buildFloor(building: f.building, level: top + 1, span: roof.span), to: &f.world)
        let shaft = try #require(f.world.rooms.values.first { $0.definitionID == "elevator-shaft" })
        try construction.apply(.resizeRoom(shaft.id, floors: FloorSpan(lowest: shaft.floors.lowest, highest: top + 1)), to: &f.world)
        var rooms: [RoomID] = []
        for (i, def) in ["hotel-twin", "hotel-single"].enumerated() {
            let width = def == "hotel-twin" ? 8 : 6
            let start = roof.span.start + i * 9
            let applied = try construction.apply(.placeRoom(building: f.building, definition: def, columns: ColumnSpan(start: start, count: width),
                                                            floors: FloorSpan(lowest: top + 1, highest: top + 1)), to: &f.world)
            rooms.append(try #require(applied.createdRoom))
        }
        for role in staff {
            FacilitiesManagement.hire(role, building: f.building, world: &f.world, rules: f.library.simulationRules)
        }
        f.engine.replanAfterConstruction(&f.world)
        return (f, rooms)
    }

    @Test func contentHasHotelRooms() throws {
        let rules = try ContentLibrary.loadBase().simulationRules
        let twin = try #require(rules.hotel(for: "hotel-twin"))
        #expect(twin.guests == 2 && twin.bookingHours == 9)
        #expect(rules.hotel(for: "apartment-studio") == nil)
    }

    @Test func invalidHotelsAreRejected() throws {
        let rooms = try ContentLibrary.loadBase().buildCatalog.specs
        let leased = HotelSpec(room: "apartment-studio", guests: 2, nightlyRate: 100, checkIn: "15:00", lastCheckIn: "22:00", checkOut: "10:00", bookingChance: 0.5)
        #expect(leased.problems(rooms: rooms).contains { $0.contains("without rentPerModule") })
        let backwards = HotelSpec(room: "hotel-twin", guests: 2, nightlyRate: 100, checkIn: "09:00", lastCheckIn: "22:00", checkOut: "10:00", bookingChance: 2)
        #expect(backwards.problems(rooms: rooms).count == 2)
    }

    /// Guests arrive in the evening, sleep in their room and leave in the morning; the night
    /// is paid at checkout, and a housekeeper makes the room up for the next guests.
    @Test func aNightIsBookedSleptPaidAndHousekept() throws {
        var (f, rooms) = try hotelFixture(staff: [.housekeeper])
        var sawGuestsInRooms = false, sawBooking = false
        for _ in 0..<(3 * 24) {
            f.engine.advance(&f.world, by: 3600)
            let hotel = f.world.hotel ?? HotelState()
            if !hotel.stays.isEmpty { sawBooking = true }
            let second = SimClock.secondOfDay(f.world.clock.tick)
            if second >= 2 * 3600 && second <= 5 * 3600 {
                // Deep in the night every booked room's guests are in it.
                for stay in hotel.stays where stay.booked < f.world.clock.tick - 3 * 3600 {
                    let inside = stay.guests.filter { id in
                        if case let .room(r, _)? = f.world.people[id]?.place { return r == stay.room } else { return false }
                    }
                    #expect(inside.count == stay.guests.count)
                    if !inside.isEmpty { sawGuestsInRooms = true }
                }
            }
        }
        let hotel = try #require(f.world.hotel)
        #expect(sawBooking && sawGuestsInRooms)
        // Housekept after each stay, the rooms are booked night after night.
        #expect(hotel.nights > rooms.count && hotel.income > 0)
        #expect(f.world.ledger.journal.contains { $0.category == .hotel && rooms.contains($0.room ?? RoomID(raw: 0)) })
        #expect(!f.world.people.values.contains { $0.role == .guest && $0.visit.map { !rooms.contains($0) } ?? true })
        try f.world.validateIntegrity(isShaft: { f.library.buildCatalog.spec($0)?.kind == .shaft })
    }

    /// Night after night for more than a week: the housekeeper keeps up, bookings go on (a
    /// technician keeps the only elevator running; without one it breaks down on day 4).
    @Test func bookingsGoOnForDays() throws {
        var (f, rooms) = try hotelFixture(staff: [.housekeeper, .janitor, .technician])
        var lateNights = 0
        for day in 0..<10 {
            for _ in 0..<24 { f.engine.advance(&f.world, by: 3600) }
            if day >= 5 { lateNights += f.world.hotel?.stays.count ?? 0 }
        }
        #expect(lateNights > 0)
        #expect((f.world.facilities.housekept ?? 0) >= rooms.count)
        #expect(!f.world.facilities.jobs.contains { $0.kind == .housekeeping && $0.created < f.world.clock.tick - 2 * SimClock.secondsPerDay })
    }

    /// Janitors clean the building, not the hotel rooms between guests: without a housekeeper
    /// a room that has had guests is not booked again.
    @Test func noHousekeepingNoNextGuests() throws {
        var (f, rooms) = try hotelFixture(staff: [.janitor, .janitor])
        for _ in 0..<(3 * 24) { f.engine.advance(&f.world, by: 3600) }
        let hotel = try #require(f.world.hotel)
        for room in rooms where hotel.needsHousekeeping(room) {
            #expect(hotel.stay(in: room) == nil)
        }
        #expect(hotel.nights >= 1 && hotel.nights <= rooms.count)            // each room at most one night
        #expect(f.world.facilities.housekept == nil)
    }
}
