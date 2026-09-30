import Foundation
import SkylineCore

/// Hotel rooms (0.30), as in the classic tower games: from the afternoon, a vacant, cleaned
/// room may be booked for the night. Its guests arrive within the hour, sleep there and check
/// out in the morning, when the night is paid. The room then waits for housekeeping: it can
/// only be booked again once a janitor has cleaned it.
extension SimulationEngine {
    // MARK: Hourly (part of the market event)

    /// Settles the stays that ended, then books rooms for tonight. Returns the new guests
    /// (their events need queuing).
    func runHotels(at now: Tick, world: inout GameWorld, services: [BuildingID: UtilityService]) -> [PersonID] {
        guard !rules.hotels.isEmpty else { return [] }
        var state = world.hotel ?? HotelState()
        checkOut(due: now, state: &state, world: &world)
        state.awaitingHousekeeping.removeAll { !world.rooms.contains($0) }
        state.stays.removeAll { !world.rooms.contains($0.room) }            // demolished: their guests have left
        let second = SimClock.secondOfDay(now)
        var added: [PersonID] = []
        for room in world.rooms.values {                                        // id order: deterministic
            guard let spec = rules.hotel(for: room.definitionID), let times = spec.times,
                  second >= times.checkIn, second <= times.lastCheckIn,
                  state.stay(in: room.id) == nil, !state.needsHousekeeping(room.id),
                  !world.incidents.isOnFire(room.buildingID), let city = world.city(of: room.buildingID) else { continue }
            let demand = city.economy.demand * (weatherKind(city)?.effects.demand ?? 1)
                * Progression.demandMultiplier(world: world, engine: self, buildings: [room.buildingID])
            let quality = Leasing.servicesLevel(of: room, world: world, service: services[room.buildingID])
            let tonight = min(1, spec.bookingChance * demand * quality)
            // Spread over the booking hours so the night's chance stays `tonight`.
            let hourly = 1 - pow(1 - tonight, 1 / Double(spec.bookingHours))
            var rng = SeededRandom(seed: city.seed ^ (UInt64(room.id.raw) &* 0x9E37_79B9_7F4A_7C15), stream: now / 3600 &+ 0x407E_1000)
            guard rng.unit() < hourly else { continue }
            let morning = SimClock.nextTick(atSecondOfDay: times.checkOut, onOrAfter: now)   // hours away: > 45 minutes
            let checkOut = max(morning - 2700 + Tick(rng.int(in: 0..<5400)), now + 3600)      // ±45 minutes
            let guests = (0..<spec.guests).map { _ in
                addGuest(to: room.id, building: room.buildingID, arriving: now + Tick(rng.int(in: 0..<3600)), world: &world)
            }
            state.stays.append(HotelStay(room: room.id, guests: guests, booked: now, checkOut: checkOut,
                                         rate: Int((Double(spec.nightlyRate) * city.economy.rent).rounded())))
            added += guests
        }
        world.hotel = state
        return added
    }

    /// Stays whose checkout has come: the night is paid and the room needs housekeeping.
    private func checkOut(due now: Tick, state: inout HotelState, world: inout GameWorld) {
        for stay in state.stays where stay.checkOut <= now {
            guard let room = world.rooms[stay.room] else { continue }
            let name = catalog.spec(room.definitionID)?.name ?? room.definitionID
            if stay.rate > 0 {
                world.ledger.post(Transaction(tick: now, amount: stay.rate, category: .hotel,
                                              detail: "Hotel — \(name), \(FloorLabel.label(for: room.floors.lowest)), one night",
                                              building: room.buildingID, room: room.id))
            }
            state.nights += 1
            state.income += stay.rate
            if !state.awaitingHousekeeping.contains(room.id) {
                state.awaitingHousekeeping.append(room.id)
                state.awaitingHousekeeping.sort()
            }
            if !world.facilities.jobs.contains(where: { $0.room == room.id && $0.kind == .clean }) {
                world.facilities.jobs.append(FacilityJob(room: room.id, kind: .clean, created: now))
            }
        }
        state.stays.removeAll { $0.checkOut <= now }
    }

    private func addGuest(to room: RoomID, building: BuildingID, arriving: Tick, world: inout GameWorld) -> PersonID {
        let id = world.makePersonID()
        var prng = SeededRandom(seed: UInt64(id.raw), stream: 0x4057)
        let traits = UInt32(truncatingIfNeeded: prng.next())
        let names = rules.names
        let name = names.first[prng.int(in: 0..<names.first.count)] + " " + names.last[prng.int(in: 0..<names.last.count)]
        var person = Person(id: id, name: name, age: prng.int(in: 18..<80), role: .guest, scheduleID: "", buildingID: building,
                            homeRoom: nil, workRoom: nil, place: .outside, nextEventTick: arriving, nextGoal: .visit, traits: traits)
        person.visit = room
        world.people.insert(person)
        return id
    }

    // MARK: A guest's events

    /// Go in, stay the night, leave at checkout. Someone who cannot get in or out (no route,
    /// the room gone) leaves the simulation.
    func handleGuest(_ id: PersonID, at now: Tick, world: inout GameWorld, events: inout Events) {
        guard var p = world.people[id] else { return }
        guard let building = world.buildings[p.buildingID], let roomID = p.visit, let room = world.rooms[roomID] else {
            leave(&p)
            world.people.update(id) { $0 = p }
            return
        }
        let stay = world.hotel?.stay(in: roomID)
        switch p.place {
        case let .travelling(_, destination):
            if case let .room(r, x) = destination, r == roomID, let stay {
                p.place = .room(r, x: x)
                p.nextEventTick = max(stay.checkOut, now + 60)
                p.nextGoal = .outside
            } else {
                leave(&p)
            }
        case let .room(_, x):
            if !startTrip(&p, from: Spot(floor: room.floors.lowest, x: x), to: .outside, building: building, world: world, now: now) {
                leave(&p)
            }
        case .outside:
            let target = Destination.room(roomID, x: RoutePlanner.standingSpot(in: room, traits: p.traits, grid: world.grid).x)
            guard p.nextGoal == .visit, stay != nil, let street = RoutePlanner.street(of: building, rules: rules),
                  startTrip(&p, from: street, to: target, building: building, world: world, now: now) else {
                leave(&p)
                break
            }
        case .waiting, .riding:
            return                                                              // the cars handle them
        }
        world.people.update(id) { $0 = p }
        if p.nextEventTick > now, p.nextEventTick != .max { events.push(p.nextEventTick, .person(id)) }
    }

    /// Gone for good: purged with the visitors at the next hour.
    private func leave(_ p: inout Person) {
        p.place = .outside
        p.pendingRide = nil
        p.nextGoal = nil
        p.nextEventTick = .max
    }
}
