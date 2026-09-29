import Foundation
import SkylineCore

/// Upkeep bookkeeping and staff management (Phase 10).
public enum FacilitiesManagement {
    /// One `Upkeep` per room; jobs and assignments of removed rooms are dropped.
    static func sync(_ world: inout GameWorld) {
        for u in world.upkeep.values where !world.rooms.contains(u.id) { world.upkeep.remove(u.id) }
        for room in world.rooms.values where !world.upkeep.contains(room.id) { world.upkeep.insert(Upkeep(id: room.id)) }
        world.facilities.jobs.removeAll { !world.rooms.contains($0.room) }
        for p in world.people.values where p.job.map({ !world.rooms.contains($0.room) }) ?? false {
            world.people.update(p.id) { $0.job = nil }
        }
    }

    static func isInSync(_ world: GameWorld) -> Bool {
        world.upkeep.count == world.rooms.count && world.rooms.values.allSatisfy { world.upkeep.contains($0.id) }
    }

    public static func staff(_ role: PersonRole, in world: GameWorld) -> [Person] {
        world.people.values.filter { $0.role == role }
    }

    // MARK: Staff rooms (Phase E)

    /// Staff rooms of a building (rooms whose spec houses staff), in id order.
    static func staffRooms(in building: BuildingID, world: GameWorld, catalog: BuildCatalog) -> [Room] {
        world.rooms(in: building).filter { catalog.spec($0.definitionID)?.staffPerModule != nil }
    }

    /// How many staff the building's staff rooms house; nil when the content has no staff
    /// rooms at all (then hiring is unlimited, as before Phase E).
    public static func staffCapacity(of building: BuildingID, world: GameWorld, catalog: BuildCatalog) -> Int? {
        guard catalog.specs.contains(where: { $0.staffPerModule != nil }) else { return nil }
        return staffRooms(in: building, world: world, catalog: catalog).reduce(0) {
            $0 + Int((Double($1.columns.count) * (catalog.spec($1.definitionID)?.staffPerModule ?? 0)).rounded(.down))
        }
    }

    public static func staffCount(of building: BuildingID, world: GameWorld) -> Int {
        world.people.values.reduce(0) { $0 + ($1.role.isStaff && $1.buildingID == building ? 1 : 0) }
    }

    /// The staff room nearest to a floor (fewest floors away, then id), if any. `among`: the
    /// building's staff rooms when the caller already has them (`StaffRoomDirectory`).
    static func nearestStaffRoom(to floor: Int, in building: BuildingID, world: GameWorld, catalog: BuildCatalog,
                                 among rooms: [Room]? = nil) -> Room? {
        (rooms ?? staffRooms(in: building, world: world, catalog: catalog)).min {
            (abs($0.floors.lowest - floor), $0.id) < (abs($1.floors.lowest - floor), $1.id)
        }
    }

    /// Whether a job on `floor` is within reach of a staff room (always, when the content
    /// has no staff rooms).
    static func isNearStaffRoom(_ floor: Int, in building: BuildingID, world: GameWorld, catalog: BuildCatalog,
                                among rooms: [Room]? = nil) -> Bool {
        guard catalog.specs.contains(where: { $0.staffPerModule != nil }) else { return true }
        return (rooms ?? staffRooms(in: building, world: world, catalog: catalog)).contains { room in
            let range = catalog.spec(room.definitionID)?.staffRange ?? 0
            return abs(room.floors.lowest - floor) <= range
        }
    }

    /// Hires one janitor or technician for a building; they start at the next shift. With a
    /// `catalog`, the building's staff rooms must have a free place (Phase E).
    @discardableResult
    public static func hire(_ role: PersonRole, building: BuildingID, world: inout GameWorld, rules: SimulationRules,
                            catalog: BuildCatalog? = nil) -> PersonID? {
        guard role.isStaff, let shift = rules.facilities?.shift, world.buildings.contains(building),
              world.restrictions?.staffForbidden != true else { return nil }
        if let catalog, let capacity = staffCapacity(of: building, world: world, catalog: catalog),
           staffCount(of: building, world: world) >= capacity { return nil }
        let id = world.makePersonID()
        var rng = SeededRandom(seed: UInt64(id.raw), stream: 0x57A)
        let traits = UInt32(truncatingIfNeeded: rng.next())
        let name = rules.names.first[rng.int(in: 0..<rules.names.first.count)] + " " + rules.names.last[rng.int(in: 0..<rules.names.last.count)]
        let now = world.clock.tick
        let sod = SimClock.secondOfDay(now)
        let start = sod >= shift.start && sod < shift.end ? now : SimClock.nextTick(atSecondOfDay: shift.start, onOrAfter: now)
        world.people.insert(Person(id: id, name: name, age: rng.int(in: 20..<64), role: role, scheduleID: "", buildingID: building,
                                   homeRoom: nil, workRoom: nil, place: .outside, nextEventTick: start, nextGoal: nil, traits: traits))
        return id
    }

    /// Lets the most recently hired janitor or technician go (their job returns to the list).
    @discardableResult
    public static func dismiss(_ role: PersonRole, world: inout GameWorld) -> Bool {
        guard let last = staff(role, in: world).last else { return false }
        for i in world.facilities.jobs.indices where world.facilities.jobs[i].assignee == last.id { world.facilities.jobs[i].assignee = nil }
        if case let .riding(ride, _) = last.place { world.elevators.update(ride.shaft) { $0.passengers.removeAll { $0 == last.id } } }
        world.people.remove(last.id)
        return true
    }
}

extension SimulationEngine {
    // MARK: Daily upkeep (06:00 closing)

    /// Wear and dirt accumulate, jobs are opened for rooms below the thresholds, wages paid.
    func facilitiesDaily(at now: Tick, world: inout GameWorld) {
        guard let rules = rules.facilities else { return }
        // Each room wears with the weather of its own city.
        var weatherOf: [BuildingID: WeatherKind.Effects] = [:]
        for b in world.buildings.values { weatherOf[b.id] = weatherKind(world.city(of: b.id))?.effects }
        var members: [RoomID: Int] = [:]
        for p in world.people { if let r = p.anchorRoom { members[r, default: 0] += 1 } }
        for room in world.rooms.values {
            guard let spec = catalog.spec(room.definitionID), var u = world.upkeep[room.id] else { continue }
            let weather = weatherOf[room.buildingID]
            u.condition = max(0, u.condition - (spec.wearPerDay ?? 0) * (weather?.wear ?? 1))
            if spec.kind == .room {
                let dirt = spec.category == "circulation" ? rules.circulationDirtPerDay : rules.dirtPerPersonPerDay * Double(members[room.id] ?? 0)
                u.cleanliness = max(0, u.cleanliness - dirt * (weather?.dirt ?? 1))
            }
            world.upkeep.update(room.id) { $0 = u }
            let open = Set(world.facilities.jobs.filter { $0.room == room.id }.map(\.kind))
            if spec.kind == .room, u.cleanliness < rules.cleanBelow, !open.contains(.clean) {
                world.facilities.jobs.append(FacilityJob(room: room.id, kind: .clean, created: now))
            }
            let repairAt = spec.utilitySupply != nil ? rules.equipmentRepairBelow : rules.repairBelow
            if spec.wearPerDay != nil, u.condition < repairAt, !open.contains(.repair) {
                world.facilities.jobs.append(FacilityJob(room: room.id, kind: .repair, created: now))
            }
        }
        let janitors = FacilitiesManagement.staff(.janitor, in: world).count
        let technicians = FacilitiesManagement.staff(.technician, in: world).count
        let wages = janitors * rules.janitorWagePerDay + technicians * rules.technicianWagePerDay
        if wages > 0 {
            world.ledger.post(Transaction(tick: now, amount: -wages, category: .wages,
                                          detail: "Wages — \(janitors) janitor\(janitors == 1 ? "" : "s"), \(technicians) technician\(technicians == 1 ? "" : "s")"))
        }
    }

    // MARK: Staff behaviour

    /// A staff member's event: arrival, start or end of work, or looking for work. During
    /// the shift they take the most urgent open job of their kind and travel there (service
    /// elevators allowed); off shift they go home (outside).
    func handleStaff(_ id: PersonID, at now: Tick, world: inout GameWorld, events: inout Events, staffRooms: inout StaffRoomDirectory) {
        guard var p = world.people[id], let rules = rules.facilities, let shift = rules.shift,
              let building = world.buildings[p.buildingID] else { return }
        if case let .travelling(_, destination) = p.place {               // arrived
            switch destination {
            case .outside: p.place = .outside
            case let .room(r, x): p.place = world.rooms.contains(r) ? .room(r, x: x) : .outside
            }
        }
        // Working on a job in this room: start, or finish.
        if case let .room(r, _) = p.place, var job = p.job, job.room == r {
            if let until = job.until {
                if now >= until { complete(job, by: id, at: now, world: &world, events: &events); p.job = nil }
            } else {
                var minutes = Double(job.kind == .clean ? rules.cleanMinutes : rules.repairMinutes)
                // Far from any staff room the tools and supplies are far too (Phase E).
                if let floor = world.rooms[r]?.floors.lowest,
                   !FacilitiesManagement.isNearStaffRoom(floor, in: building.id, world: world, catalog: catalog,
                                                                        among: staffRooms.rooms(of: building.id, world: world, catalog: catalog)) {
                    minutes *= rules.outOfRangeFactor ?? 1
                }
                job.until = now + Tick((minutes * 60).rounded())
                p.job = job
                p.nextEventTick = job.until!
                return save(p, world: &world, events: &events, now: now)
            }
        }
        let sod = SimClock.secondOfDay(now)
        let onShift = sod >= shift.start && sod < shift.end
        let here: Spot? = {
            switch p.place {
            case let .room(r, x): world.rooms[r].map { Spot(floor: $0.floors.lowest, x: x) }
            default: RoutePlanner.street(of: building, rules: self.rules)
            }
        }()
        if onShift, p.job == nil, let from = here, let job = claimJob(for: p, world: &world), let room = world.rooms[job.room] {
            let x = (world.grid.x(ofColumn: room.columns.start) + world.grid.x(ofColumn: room.columns.end)) / 2
            p.job = JobAssignment(room: job.room, kind: job.kind)
            if case let .room(r, _) = p.place, r == job.room {
                p.nextEventTick = now + 1                                  // already there: start next tick
            } else if !startTrip(&p, from: from, to: .room(job.room, x: x), building: building, world: world, now: now) {
                release(job.room, by: id, world: &world)
                p.job = nil
                p.nextEventTick = now + 900
            }
        } else if onShift {
            // Nothing to do: wait in the nearest staff room (Phase E) and check again.
            let floor: Int? = { if case let .room(r, _) = p.place { world.rooms[r]?.floors.lowest } else { 0 } }()
            let known = staffRooms.rooms(of: building.id, world: world, catalog: catalog)
            let staffRoom = floor.flatMap { FacilitiesManagement.nearestStaffRoom(to: $0, in: building.id, world: world, catalog: catalog, among: known) }
            let inStaffRoom = staffRoom.map { s in if case let .room(r, _) = p.place { r == s.id } else { false } } ?? true
            if let staffRoom, !inStaffRoom, let from = here,
               startTrip(&p, from: from, to: .room(staffRoom.id, x: RoutePlanner.standingSpot(in: staffRoom, traits: p.traits, grid: world.grid).x),
                         building: building, world: world, now: now) {
                // walking over
            } else {
                p.nextEventTick = now + 900
            }
        } else if case .outside = p.place {
            p.nextEventTick = SimClock.nextTick(atSecondOfDay: shift.start + Tick(p.traits % 600), onOrAfter: now + 1)
        } else if let from = here, startTrip(&p, from: from, to: .outside, building: building, world: world, now: now) {
            // heading home
        } else {
            p.place = .outside
            p.nextEventTick = now + 60
        }
        save(p, world: &world, events: &events, now: now)
    }

    private func save(_ p: Person, world: inout GameWorld, events: inout Events, now: Tick) {
        world.people.update(p.id) { $0 = p }
        if p.nextEventTick > now { events.push(p.nextEventTick, .person(p.id)) }
    }

    /// Takes the most urgent open job of the person's kind: failed equipment first, then the
    /// worst room (lowest condition / cleanliness), then the oldest; ties by room id.
    private func claimJob(for p: Person, world: inout GameWorld) -> FacilityJob? {
        guard let kind = p.role.jobKind else { return nil }
        let failure = rules.facilities?.failureBelow ?? 0
        func urgency(_ job: FacilityJob) -> (Int, Double, Tick, RoomID) {
            let u = world.upkeep[job.room]
            let value = kind == .clean ? (u?.cleanliness ?? 1) : (u?.condition ?? 1)
            let failed = kind == .repair && (world.elevators[job.room]?.isOutOfService == true
                || value < failure && catalog.spec(world.rooms[job.room]?.definitionID ?? "")?.utilitySupply != nil)
            return (failed ? 0 : 1, value, job.created, job.room)
        }
        let open = world.facilities.jobs.indices.filter { world.facilities.jobs[$0].kind == kind && world.facilities.jobs[$0].assignee == nil }
        guard let i = open.min(by: { urgency(world.facilities.jobs[$0]) < urgency(world.facilities.jobs[$1]) }) else { return nil }
        world.facilities.jobs[i].assignee = p.id
        return world.facilities.jobs[i]
    }

    private func release(_ room: RoomID, by id: PersonID, world: inout GameWorld) {
        for i in world.facilities.jobs.indices where world.facilities.jobs[i].room == room && world.facilities.jobs[i].assignee == id {
            world.facilities.jobs[i].assignee = nil
        }
    }

    private func complete(_ job: JobAssignment, by id: PersonID, at now: Tick, world: inout GameWorld, events: inout Events) {
        world.upkeep.update(job.room) { u in
            if job.kind == .clean { u.cleanliness = 1 } else { u.condition = 1 }
        }
        if job.kind == .repair, world.elevators[job.room]?.isOutOfService == true {
            // Back in service: the next step's navigation refresh brings routes back.
            world.elevators.update(job.room) { c in
                c.outOfService = nil
                c.nextEventTick = now
            }
            events.push(now, .car(job.room))
        }
        world.facilities.jobs.removeAll { $0.room == job.room && $0.kind == job.kind && $0.assignee == id }
        if job.kind == .clean { world.facilities.cleaned += 1 } else { world.facilities.repaired += 1 }
    }
}

/// The staff rooms of each building, looked up once per `advance` call and building (F2:
/// scanning every room per idle staff member was a third of a day's time at 500 floors).
/// Rooms only change through construction, between calls. A cache, never state.
struct StaffRoomDirectory {
    private var byBuilding: [BuildingID: [Room]] = [:]

    mutating func rooms(of building: BuildingID, world: GameWorld, catalog: BuildCatalog) -> [Room] {
        if let known = byBuilding[building] { return known }
        let found = FacilitiesManagement.staffRooms(in: building, world: world, catalog: catalog)
        byBuilding[building] = found
        return found
    }
}
