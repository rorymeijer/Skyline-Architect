import Foundation
import SkylineCore

/// A point people can stand at: a floor and an x position (meters).
struct Spot: Equatable {
    var floor: Int
    var x: Double
}

/// Minimal Phase 4 routing inside one building: street ↔ entrance on the ground floor,
/// walking along floors, one stairwell between floors. Phase 5 replaces this with a
/// hierarchical navigation graph (transfers, elevators, cached routes, invalidation).
enum RoutePlanner {
    /// Ground-floor entrance (left end of the ground plate).
    static func entrance(of building: Building) -> Spot? {
        guard let ground = building.plate(at: 0) else { return nil }
        return Spot(floor: 0, x: Double(ground.span.start) + 0.4)
    }

    static func street(of building: Building, rules: SimulationRules) -> Spot? {
        entrance(of: building).map { Spot(floor: 0, x: $0.x - rules.streetDistance) }
    }

    /// Where a person stands inside a room: a personal spot within the usable width.
    static func standingSpot(in room: Room, traits: UInt32, grid: GridSpec) -> Spot {
        let x0 = grid.x(ofColumn: room.columns.start) + 0.8
        let x1 = grid.x(ofColumn: room.columns.end) - 0.8
        let f = Double(traits % 1000) / 1000
        return Spot(floor: room.floors.lowest, x: x1 > x0 ? x0 + (x1 - x0) * f : (x0 + x1) / 2)
    }

    /// Legs from `from` to `to` starting at `now`, or nil if unreachable.
    static func plan(from: Spot, to: Spot, building: Building, world: GameWorld, catalog: BuildCatalog,
                     rules: SimulationRules, now: Tick) -> [Leg]? {
        var legs: [Leg] = []
        var t = now
        func walk(_ floor: Int, _ a: Double, _ b: Double) {
            guard abs(b - a) > 0.01 else { return }
            let d = Tick((abs(b - a) / rules.walkSpeed).rounded(.up))
            legs.append(.walk(floor: floor, fromX: a, toX: b, start: t, end: t + max(d, 1)))
            t += max(d, 1)
        }
        if from.floor == to.floor {
            walk(from.floor, from.x, to.x)
            return legs.isEmpty ? [.walk(floor: from.floor, fromX: from.x, toX: to.x, start: now, end: now + 1)] : legs
        }
        // Stairwells serving both floors; nearest overall wins (ties: lower id).
        let candidates = world.rooms(in: building.id).filter { room in
            catalog.spec(room.definitionID)?.transport == "stairs"
                && room.floors.contains(from.floor) && room.floors.contains(to.floor)
        }
        let grid = world.grid
        guard let shaft = candidates.min(by: { a, b in
            let ca = grid.x(ofColumn: a.columns.start), cb = grid.x(ofColumn: b.columns.start)
            let da = abs(ca - from.x) + abs(ca - to.x), db = abs(cb - from.x) + abs(cb - to.x)
            return da == db ? a.id < b.id : da < db
        }) else { return nil }
        let landing = 1.1
        let leftX = grid.x(ofColumn: shaft.columns.start) + landing
        let rightX = grid.x(ofColumn: shaft.columns.end) - landing
        walk(from.floor, from.x, leftX)
        let duration = Tick(abs(to.floor - from.floor)) * rules.stairsSecondsPerFloor
        legs.append(.stairs(shaft: shaft.id, fromFloor: from.floor, toFloor: to.floor, leftX: leftX, rightX: rightX,
                            start: t, end: t + duration))
        t += duration
        walk(to.floor, leftX, to.x)
        return legs
    }
}
