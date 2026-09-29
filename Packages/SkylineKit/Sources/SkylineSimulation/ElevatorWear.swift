import Foundation
import SkylineCore

/// Elevator wear and breakdowns (Phase E). Every stop wears the shaft (its `Upkeep`
/// condition); once worn below the facilities' equipment repair threshold a repair job is
/// opened, and each stop risks a breakdown — more likely the more worn. A broken car stands
/// where it is: its riders get out there, everyone who counted on it re-plans (the
/// navigation graph leaves it out), and technicians repair it first.
extension SimulationEngine {
    /// Wears the shaft for one stop. Returns true if the car breaks down now.
    func wearOnStop(_ car: RoomID, spec: ElevatorSpec, at now: Tick, world: inout GameWorld) -> Bool {
        guard let wear = spec.wearPerStop, wear > 0, let facilities = rules.facilities,
              var upkeep = world.upkeep[car] else { return false }
        upkeep.condition = max(0, upkeep.condition - wear)
        world.upkeep.update(car) { $0 = upkeep }
        let repairAt = facilities.equipmentRepairBelow
        guard upkeep.condition < repairAt else { return false }
        if !world.facilities.jobs.contains(where: { $0.room == car && $0.kind == .repair }) {
            world.facilities.jobs.append(FacilityJob(room: car, kind: .repair, created: now))
        }
        let span = max(repairAt - facilities.failureBelow, 0.01)
        let risk = (spec.breakdownChance ?? 0) * min(max((repairAt - upkeep.condition) / span, 0), 1)
        var rng = SeededRandom(seed: UInt64(car.raw), stream: now)
        return rng.unit() < risk
    }

    /// The car breaks down at `floor`: it stops for good (until repaired); riders step out
    /// here and, with everyone queuing for it or walking to it, continue another way.
    func breakDown(_ id: RoomID, at floor: Int, now: Tick, world: inout GameWorld, events: inout Events,
                   report: inout SimulationReport) {
        guard let car = world.elevators[id], let building = world.buildings[car.buildingID] else { return }
        world.elevators.update(id) { c in
            c.outOfService = true
            c.floor = floor
            c.direction = 0
            c.motion = .idle
            c.passengers = []
            c.nextEventTick = .max
        }
        world.facilities.breakdowns = (world.facilities.breakdowns ?? 0) + 1
        navigation.refresh(world: world, catalog: catalog)               // the graph now leaves the car out
        for person in world.people.values {
            let from: Spot
            let destination: Destination
            switch person.place {
            case let .riding(ride, d) where ride.shaft == id:
                from = Spot(floor: floor, x: ride.x)
                destination = d
            case let .waiting(ride, d, _) where ride.shaft == id:
                from = Spot(floor: ride.fromFloor, x: ride.x)
                destination = d
            case let .travelling(legs, d) where person.pendingRide?.shaft == id:
                guard let spot = currentSpot(legs, at: now, grid: world.grid) else { continue }
                from = spot
                destination = d
            default:
                continue
            }
            var p = person
            p.pendingRide = nil
            if !startTrip(&p, from: from, to: destination, building: building, world: world, now: now) {
                strand(&p, at: now)
                report.unreachable += 1
            }
            world.people.update(p.id) { $0 = p }
            events.push(p.nextEventTick, .person(p.id))
        }
    }
}
