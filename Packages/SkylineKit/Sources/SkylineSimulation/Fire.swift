import Foundation
import SkylineCore

/// Fire (Phase 14). Rooms ignite rarely (more often when worn or when they are plant),
/// a fire grows and spreads to neighbouring rooms step by step, sprinklers of fire control
/// rooms and later the fire brigade put it out, everybody leaves the building by the stairs
/// and stays out until it is over; then the damage is billed, destroyed units lose their
/// tenants, repairs are ordered and the building's reputation suffers. See EMERGENCIES.md.
public enum FireSafety {
    /// Rooms protected by a working fire control room (sprinklers) within its range.
    public static func protectedRooms(in building: BuildingID, world: GameWorld, catalog: BuildCatalog, failureBelow: Double) -> Set<RoomID> {
        let rooms = world.rooms(in: building)
        let stations = rooms.filter { r in
            catalog.spec(r.definitionID)?.fireProtection != nil && (world.upkeep[r.id]?.condition ?? 1) >= failureBelow
        }
        guard !stations.isEmpty else { return [] }
        var out = Set<RoomID>()
        for room in rooms {
            if stations.contains(where: { abs($0.floors.lowest - room.floors.lowest) <= (catalog.spec($0.definitionID)?.fireProtection ?? 0) }) {
                out.insert(room.id)
            }
        }
        return out
    }

    /// Rooms a fire in `room` can spread to: side by side on a shared floor, or directly
    /// above or below. Shafts are fire compartments and never burn.
    static func neighbours(of room: Room, in world: GameWorld, catalog: BuildCatalog) -> [Room] {
        world.rooms(in: room.buildingID).filter { other in
            guard other.id != room.id, catalog.spec(other.definitionID)?.kind == .room else { return false }
            let floorsOverlap = other.floors.lowest <= room.floors.highest && room.floors.lowest <= other.floors.highest
            if floorsOverlap, other.columns.end == room.columns.start || room.columns.end == other.columns.start { return true }
            return other.columns.overlaps(room.columns)
                && (other.floors.highest == room.floors.lowest - 1 || other.floors.lowest == room.floors.highest + 1)
        }
    }
}

extension SimulationEngine {
    var fireRules: EventRules.FireRules? { rules.events?.fire }

    // MARK: Ignition

    /// Hourly: each room of a building without a fire may ignite.
    func checkIgnition(at now: Tick, world: inout GameWorld, events: inout Events) {
        guard fireRules != nil else { return }
        let failure = rules.facilities?.failureBelow ?? 0
        for building in world.buildings.values where !world.incidents.isOnFire(building.id) {
            let protected = FireSafety.protectedRooms(in: building.id, world: world, catalog: catalog, failureBelow: failure)
            for room in world.rooms(in: building.id) {
                guard let chance = ignitionChancePerHour(room, world: world, protected: protected.contains(room.id)) else { continue }
                var rng = SeededRandom(seed: Weather.seed(of: world) ^ UInt64(room.id.raw), stream: 0xF14E &+ now / 3600)
                if rng.chance(chance) {
                    ignite(room.id, at: now, world: &world, events: &events)
                    break
                }
            }
        }
    }

    /// Chance that a room catches fire in one hour (nil for shafts or without fire rules).
    func ignitionChancePerHour(_ room: Room, world: GameWorld, protected: Bool) -> Double? {
        guard let fire = fireRules, let spec = catalog.spec(room.definitionID), spec.kind == .room else { return nil }
        var chance = fire.ignitionPerRoomPerDay / 24
        if (world.upkeep[room.id]?.condition ?? 1) < fire.wornBelow { chance *= fire.wornMultiplier }
        if spec.utilitySupply != nil { chance *= fire.equipmentMultiplier }
        if protected { chance *= fire.protectedIgnitionFactor }
        return chance
    }

    /// Starts a fire in a room (also the developer tool). Returns false if the building
    /// already has one or there are no fire rules.
    @discardableResult
    public func ignite(_ roomID: RoomID, at now: Tick, world: inout GameWorld) -> Bool {
        var events = Events(target: now)
        return ignite(roomID, at: now, world: &world, events: &events)
    }

    @discardableResult
    func ignite(_ roomID: RoomID, at now: Tick, world: inout GameWorld, events: inout Events) -> Bool {
        guard let fire = fireRules, let room = world.rooms[roomID], !world.incidents.isOnFire(room.buildingID) else { return false }
        let id = world.incidents.nextID
        world.incidents.nextID += 1
        let name = catalog.spec(room.definitionID)?.name ?? "room"
        world.incidents.record(Incident(id: id, kind: "fire", name: "Fire", building: room.buildingID, rooms: [roomID], started: now,
                                        ended: nil, detail: "Fire in \(name), \(FloorLabel.label(for: room.floors.lowest))"))
        world.incidents.fires.append(Fire(incident: id, building: room.buildingID,
                                          burning: [.init(room: roomID, intensity: fire.startIntensity)],
                                          brigadeArrives: now + Tick(fire.brigadeResponseMinutes * 60), nextStep: now + Tick(fire.stepSeconds)))
        events.push(now + Tick(fire.stepSeconds), .fires)
        evacuate(room.buildingID, at: now, world: &world, events: &events)
        return true
    }

    // MARK: Evacuation

    /// Everybody in the building heads out by the stairs: people in rooms after a short
    /// reaction time, people walking to or waiting at an elevator at once. Riders finish
    /// their ride and leave from where they get out (see `handleDuringFire`).
    func evacuate(_ building: BuildingID, at now: Tick, world: inout GameWorld, events: inout Events) {
        for person in world.people.values where person.buildingID == building {
            var p = person
            dropJob(&p, world: &world)
            switch p.place {
            case .room:
                p.nextEventTick = now + 20 + Tick(p.traits % 100)          // reaction time
            case let .waiting(ride, _, _):
                leave(&p, from: Spot(floor: ride.fromFloor, x: ride.x), at: now, world: world)
            case let .travelling(legs, _) where p.pendingRide != nil:
                if let spot = currentSpot(legs, at: now, grid: world.grid) { leave(&p, from: spot, at: now, world: world) }
            default:
                continue
            }
            world.people.update(p.id) { $0 = p }
            events.push(p.nextEventTick, .person(p.id))
        }
    }

    /// A person's event while their building burns: nobody goes in, everybody inside goes
    /// out. Residents return home afterwards; others resume their schedule.
    func handleDuringFire(_ id: PersonID, at now: Tick, world: inout GameWorld, events: inout Events) {
        guard var p = world.people[id] else { return }
        dropJob(&p, world: &world)
        if case let .travelling(_, destination) = p.place {             // arrived somewhere
            switch destination {
            case .outside: p.place = .outside
            case let .room(r, x): p.place = world.rooms.contains(r) ? .room(r, x: x) : .outside
            }
        }
        if p.role == .visitor || p.role == .guest, p.place == .outside {   // visitors and guests go home
            p.nextGoal = nil
            p.nextEventTick = .max
            world.people.update(id) { $0 = p }
            return
        }
        switch p.place {
        case let .room(r, x):
            let spot = world.rooms[r].map { Spot(floor: $0.floors.lowest, x: x) }
            if let spot { leave(&p, from: spot, at: now, world: world) } else { p.place = .outside }
            if p.place == .outside { p.nextEventTick = now + 600 }
            p.nextGoal = nil
        case .outside:
            // Check again later; by then they want to be where their schedule says now, so
            // when the fire is out they go back to work or home — or stay out after hours.
            p.nextEventTick = now + 600
            p.nextGoal = rules.schedule(p.scheduleID).flatMap { rules.currentGoal(at: now + 600, schedule: $0, traits: p.traits) }
        default:
            break                                                          // queues and rides are handled by the cars
        }
        world.people.update(id) { $0 = p }
        if p.nextEventTick > now { events.push(p.nextEventTick, .person(id)) }
    }

    /// Staff drop their job (it returns to the list) when they have to get out.
    private func dropJob(_ p: inout Person, world: inout GameWorld) {
        guard p.job != nil else { return }
        p.job = nil
        for i in world.facilities.jobs.indices where world.facilities.jobs[i].assignee == p.id { world.facilities.jobs[i].assignee = nil }
    }

    private func leave(_ p: inout Person, from spot: Spot, at now: Tick, world: GameWorld) {
        guard let building = world.buildings[p.buildingID],
              startTrip(&p, from: spot, to: .outside, building: building, world: world, now: now, stairsOnly: true) else {
            p.place = .outside
            p.pendingRide = nil
            return
        }
    }
}
