import Foundation
import SkylineCore

/// A point people can stand at: a floor and an x position (meters).
struct Spot: Equatable {
    var floor: Int
    var x: Double
}

/// Trip planning inside one building: street ↔ entrance on the ground floor, walking along
/// floors, vertical transport found through the `NavigationGraph` (via `NavigationService`).
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

    /// Legs from `from` to `to` starting at `now`, or nil if unreachable. Same-floor trips are
    /// one walk; otherwise the navigation graph supplies the portal sequence (stairs, transfers).
    static func plan(from: Spot, to: Spot, building: Building, world: GameWorld, navigation: NavigationService,
                     catalog: BuildCatalog, rules: SimulationRules, now: Tick) -> [Leg]? {
        if from.floor == to.floor {
            return legs([.walk(floor: from.floor, from: from.x, to: to.x)], rules: rules, now: now)
                ?? [.walk(floor: from.floor, fromX: from.x, toX: to.x, start: now, end: now + 1)]
        }
        guard let (graph, path) = navigation.path(from: from, to: to, building: building, world: world,
                                                  catalog: catalog, rules: rules) else { return nil }
        return legs(segments(from: from, to: to, path: path, graph: graph), rules: rules, now: now)
    }

    enum Segment: Equatable {
        case walk(floor: Int, from: Double, to: Double)
        case stairs(shaft: RoomID, fromFloor: Int, toFloor: Int, leftX: Double, rightX: Double)
    }

    /// Walk to the first portal, follow the portals, walk to the target. Consecutive walks on
    /// a floor and consecutive storeys on one shaft merge into single segments.
    static func segments(from: Spot, to: Spot, path: [Int], graph: NavigationGraph) -> [Segment] {
        var out: [Segment] = []
        func add(_ s: Segment) {
            switch (out.last, s) {
            case let (.walk(f0, a, _)?, .walk(f1, _, b)) where f0 == f1:
                out[out.count - 1] = .walk(floor: f0, from: a, to: b)
            case let (.stairs(s0, lo, _, l, r)?, .stairs(s1, _, hi, _, _)) where s0 == s1:
                out[out.count - 1] = .stairs(shaft: s0, fromFloor: lo, toFloor: hi, leftX: l, rightX: r)
            default:
                out.append(s)
            }
        }
        var here = from
        for index in path {
            let portal = graph.portals[index]
            if portal.floor == here.floor {
                add(.walk(floor: here.floor, from: here.x, to: portal.x))
            } else if let shaft = graph.shaft(portal.shaft) {
                add(.stairs(shaft: shaft.id, fromFloor: here.floor, toFloor: portal.floor, leftX: shaft.leftX, rightX: shaft.rightX))
            }
            here = Spot(floor: portal.floor, x: portal.x)
        }
        add(.walk(floor: to.floor, from: here.x, to: to.x))
        return out
    }

    /// Timed legs for segments; walks shorter than 1 cm are dropped. Nil if nothing remains.
    static func legs(_ segments: [Segment], rules: SimulationRules, now: Tick) -> [Leg]? {
        var legs: [Leg] = []
        var t = now
        for segment in segments {
            switch segment {
            case let .walk(floor, a, b):
                guard abs(b - a) > 0.01 else { continue }
                let d = max(Tick((abs(b - a) / rules.walkSpeed).rounded(.up)), 1)
                legs.append(.walk(floor: floor, fromX: a, toX: b, start: t, end: t + d))
                t += d
            case let .stairs(shaft, f0, f1, l, r):
                let d = Tick(abs(f1 - f0)) * rules.stairsSecondsPerFloor
                legs.append(.stairs(shaft: shaft, fromFloor: f0, toFloor: f1, leftX: l, rightX: r, start: t, end: t + d))
                t += d
            }
        }
        return legs.isEmpty ? nil : legs
    }
}
