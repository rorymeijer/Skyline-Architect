import Foundation
import SkylineCore

/// The open-able amenities of the world (0.22): every leased amenity room with its offer,
/// plus how many workers and residents each building has (for the share that fits). Built
/// from rooms, tenants and people; rebuilt whenever tenants may have changed (per `advance`
/// call and after each market hour). A cache, never state.
struct AmenityDirectory {
    struct Venue {
        let room: RoomID
        let floor: Int
        let spec: AmenitySpec
        let capacity: Int
        let tenant: TenantID
    }

    private(set) var venues: [BuildingID: [Venue]] = [:]
    private var byRoom: [RoomID: Venue] = [:]
    private var workers: [BuildingID: Int] = [:]
    private var residents: [BuildingID: Int] = [:]

    init(world: GameWorld, rules: SimulationRules) {
        guard !rules.amenities.isEmpty else { return }
        for tenant in world.tenants {                                   // id order: venues in lease order
            guard let room = world.rooms[tenant.room], let spec = rules.amenity(for: room.definitionID) else { continue }
            let venue = Venue(room: room.id, floor: room.floors.lowest, spec: spec,
                              capacity: spec.capacity(modules: room.columns.count), tenant: tenant.id)
            venues[room.buildingID, default: []].append(venue)
            byRoom[room.id] = venue
        }
        guard !venues.isEmpty else { return }
        for p in world.people where venues[p.buildingID] != nil {
            switch p.role {
            case .worker: workers[p.buildingID, default: 0] += 1
            case .resident: residents[p.buildingID, default: 0] += 1
            case .visitor, .guest, .janitor, .technician, .housekeeper: break
            }
        }
    }

    var isEmpty: Bool { venues.isEmpty }

    func venue(_ room: RoomID) -> Venue? { byRoom[room] }

    /// Where someone of the building spends their lunch break or free time, if anywhere:
    /// open venues serving the occasion that stay open another 20 minutes. Everyone gets a
    /// seat only as long as the seats go round (seats ÷ workers or residents), then a venue
    /// weighted by its seats. Deterministic per person and day.
    func pick(_ occasion: AmenityOccasion, for p: Person, building: BuildingID, now: Tick) -> Venue? {
        let second = SimClock.secondOfDay(now)
        let open = (venues[building] ?? []).filter {
            $0.spec.serves(occasion) && $0.spec.secondsUntilClosing(atSecondOfDay: second) >= 1200
        }
        guard !open.isEmpty else { return nil }
        let seats = open.reduce(0) { $0 + $1.capacity }
        let people = (occasion == .lunch ? workers[building] : residents[building]) ?? 0
        var rng = SeededRandom(seed: UInt64(p.traits), stream: SimClock.day(now) &* 8 &+ (occasion == .lunch ? 1 : 2) &+ 0xA3E0_0000)
        guard rng.unit() < Double(seats) / Double(max(people, 1)) else { return nil }
        var pick = rng.int(in: 0..<seats)
        for v in open {
            if pick < v.capacity { return v }
            pick -= v.capacity
        }
        return open.last
    }
}

extension SimulationEngine {
    // MARK: Street visitors

    /// Hourly (part of the market event): street visitors for every open venue, spread over
    /// the hour. Their number follows the venue's width, busy hours, the city's demand, the
    /// weather, the building's reputation and — for a view — its height; at most as many as
    /// the seats turn over in an hour. Returns the new people (their events need queuing).
    func spawnVisitors(at now: Tick, world: inout GameWorld) -> [PersonID] {
        let directory = AmenityDirectory(world: world, rules: rules)
        guard !directory.isEmpty else { return [] }
        let second = SimClock.secondOfDay(now)
        let hour = Int(second / 3600)
        var added: [PersonID] = []
        for building in world.buildings.values {
            guard let venues = directory.venues[building.id], !world.incidents.isOnFire(building.id),
                  let city = world.city(of: building.id) else { continue }
            let demand = city.economy.demand * (weatherKind(city)?.effects.demand ?? 1)
                * Progression.demandMultiplier(world: world, engine: self, buildings: [building.id])
            for venue in venues {
                let spec = venue.spec
                let stay = Tick(spec.stayMinutes * 60)
                let open = spec.secondsUntilClosing(atSecondOfDay: second)
                guard open > stay / 2, let room = world.rooms[venue.room] else { continue }
                let busy = (spec.busyHours ?? []).contains(hour) ? 2.0 : 1.0
                let height = 1 + (spec.heightBonusPerFloor ?? 0) * Double(max(venue.floor, 0))
                let rate = spec.streetVisitorsPerModulePerHour * Double(room.columns.count) * busy * demand * height
                let turnover = Double(venue.capacity) * 3600 / Double(max(stay, 60))
                let expected = min(rate, turnover)
                var rng = SeededRandom(seed: city.seed ^ (UInt64(venue.room.raw) &* 0x9E37_79B9_7F4A_7C15),
                                       stream: now / 3600)
                let count = Int(expected) + (rng.unit() < expected - Double(Int(expected)) ? 1 : 0)
                let window = min(3600, open - stay / 2)
                for _ in 0..<count {
                    added.append(addVisitor(to: venue.room, building: building.id, arriving: now + Tick(rng.int(in: 0..<Int(window))),
                                            world: &world))
                }
            }
        }
        return added
    }

    private func addVisitor(to room: RoomID, building: BuildingID, arriving: Tick, world: inout GameWorld) -> PersonID {
        let id = world.makePersonID()
        var prng = SeededRandom(seed: UInt64(id.raw), stream: 0x71517)
        let traits = UInt32(truncatingIfNeeded: prng.next())
        let names = rules.names
        let name = names.first[prng.int(in: 0..<names.first.count)] + " " + names.last[prng.int(in: 0..<names.last.count)]
        var person = Person(id: id, name: name, age: prng.int(in: 16..<82), role: .visitor, scheduleID: "", buildingID: building,
                            homeRoom: nil, workRoom: nil, place: .outside, nextEventTick: arriving, nextGoal: .visit, traits: traits)
        person.visit = room
        world.people.insert(person)
        return id
    }

    /// Visitors and hotel guests who have left the building are dropped (hourly, in one pass).
    func purgeDepartedVisitors(_ world: inout GameWorld) {
        world.people.removeAll { ($0.role == .visitor || $0.role == .guest) && $0.place == .outside && $0.nextGoal == nil }
    }

    /// A visitor's event: go in, stay a while, leave. Someone who cannot get in or out (the
    /// venue closed, no route) just goes home: they leave the simulation.
    func handleVisitor(_ id: PersonID, at now: Tick, world: inout GameWorld, events: inout Events, directory: AmenityDirectory) {
        guard var p = world.people[id] else { return }
        guard let building = world.buildings[p.buildingID], let roomID = p.visit, let room = world.rooms[roomID] else {
            depart(&p)
            world.people.update(id) { $0 = p }
            return
        }
        switch p.place {
        case let .travelling(_, destination):
            if case let .room(r, x) = destination, r == roomID {
                p.place = .room(r, x: x)
                let spec = directory.venue(roomID)?.spec
                recordVisit(roomID, fromStreet: true, at: now, world: &world, directory: directory)
                // Personal stay ±30 %, never past closing time.
                let base = Double((spec?.stayMinutes ?? 30) * 60) * (0.7 + 0.6 * Double((p.traits >> 12) % 1000) / 1000)
                let closing = spec?.secondsUntilClosing(atSecondOfDay: SimClock.secondOfDay(now)) ?? 0
                p.nextEventTick = now + max(min(Tick(base), closing), 60)
                p.nextGoal = .outside
            } else {
                depart(&p)
            }
        case let .room(_, x):
            if !startTrip(&p, from: Spot(floor: room.floors.lowest, x: x), to: .outside, building: building, world: world, now: now) {
                depart(&p)
            }
        case .outside:
            let open = directory.venue(roomID).map { $0.spec.secondsUntilClosing(atSecondOfDay: SimClock.secondOfDay(now)) > 600 } ?? false
            let target = Destination.room(roomID, x: RoutePlanner.standingSpot(in: room, traits: p.traits, grid: world.grid).x)
            guard open, p.nextGoal == .visit, let street = RoutePlanner.street(of: building, rules: rules),
                  startTrip(&p, from: street, to: target, building: building, world: world, now: now) else {
                depart(&p)
                break
            }
        case .waiting, .riding:
            return                                                         // the cars handle them
        }
        world.people.update(id) { $0 = p }
        if p.nextEventTick > now, p.nextEventTick != .max { events.push(p.nextEventTick, .person(id)) }
    }

    /// Gone for good: purged at the next hour.
    private func depart(_ p: inout Person) {
        p.place = .outside
        p.pendingRide = nil
        p.nextGoal = nil
        p.nextEventTick = .max
    }

    // MARK: Takings

    /// A customer arrives: the venue's operator takes the visit's spend (at the city's price level).
    func recordVisit(_ room: RoomID, fromStreet: Bool, at now: Tick, world: inout GameWorld, directory: AmenityDirectory) {
        guard let venue = directory.venue(room), let tenant = world.tenants[venue.tenant], tenant.room == room else { return }
        let price = world.city(of: tenant.buildingID)?.economy.rent ?? 1
        let amount = Int((Double(venue.spec.spendPerVisit) * price).rounded())
        world.tenants.update(venue.tenant) { t in
            var sales = t.sales ?? AmenitySales()
            sales.record(takings: amount, fromStreet: fromStreet)
            t.sales = sales
        }
    }

    /// Daily closing (from `closeDay`): the landlord's share of every venue's takings, then
    /// the day's figures become yesterday's.
    func postTurnover(at now: Tick, world: inout GameWorld) {
        for tenant in world.tenants.values {
            guard var sales = tenant.sales else { continue }
            let share = world.rooms[tenant.room].flatMap { rules.amenity(for: $0.definitionID)?.turnoverShare } ?? 0
            let amount = Int((Double(sales.takings) * share).rounded())
            if amount > 0 {
                world.ledger.post(Transaction(tick: now, amount: amount, category: .turnover,
                                              detail: "Turnover share — \(tenant.name) (\(sales.visits) customers)",
                                              building: tenant.buildingID, room: tenant.room, tenant: tenant.id))
            }
            sales.closeDay()
            world.tenants.update(tenant.id) { $0.sales = sales }
        }
    }

    // MARK: Appeal

    /// How much the open amenities make a building's other units more attractive: each kind
    /// of amenity counts once (content order, so the sum is deterministic). Per building,
    /// from one pass over the tenants.
    public func amenityAppeal(_ world: GameWorld) -> [BuildingID: Double] {
        guard !rules.amenities.isEmpty else { return [:] }
        var kinds: [BuildingID: Set<String>] = [:]
        for tenant in world.tenants {
            guard let room = world.rooms[tenant.room], rules.amenity(for: room.definitionID) != nil else { continue }
            kinds[room.buildingID, default: []].insert(room.definitionID)
        }
        var appeal: [BuildingID: Double] = [:]
        for (building, open) in kinds {                                    // per key: order does not matter
            appeal[building] = rules.amenities.reduce(0) { $0 + (open.contains($1.room) ? $1.appeal ?? 0 : 0) }
        }
        return appeal
    }
}
