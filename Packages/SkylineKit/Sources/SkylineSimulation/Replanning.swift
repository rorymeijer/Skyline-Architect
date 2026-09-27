import Foundation
import SkylineCore

public struct ReplanReport: Equatable, Sendable {
    /// Travellers whose route used removed structure and got a new one.
    public var replanned = 0
    /// Travellers with no route left from where they were; they left the building.
    public var stranded = 0
}

extension SimulationEngine {
    /// Re-plans trips invalidated by construction. A trip is invalid when a remaining leg
    /// walks where there is no floor or uses a shaft that no longer serves those floors.
    /// Affected people continue from where they are now (people on stairs step onto the
    /// nearest landing); if no route remains they leave the building and are marked
    /// unreachable. Trips that are still valid are kept even if a faster route appeared.
    ///
    /// Runs automatically at the start of `advance` when the structure changed; the app also
    /// calls it right after a command so a paused game never shows people on removed stairs.
    @discardableResult
    public func replanAfterConstruction(_ world: inout GameWorld) -> ReplanReport {
        navigation.refresh(world: world, catalog: catalog)
        var report = ReplanReport()
        let now = world.clock.tick
        var graphs: [BuildingID: NavigationGraph] = [:]
        for person in world.people.values {
            guard case let .travelling(legs, destination) = person.place,
                  let building = world.buildings[person.buildingID] else { continue }
            let graph = graphs[building.id] ?? navigation.graph(for: building, world: world, catalog: catalog, rules: rules)
            graphs[building.id] = graph
            let remaining = legs.filter { $0.end > now }
            guard !remaining.allSatisfy({ Self.isValid($0, in: graph) }),
                  let position = currentSpot(legs, at: now, grid: world.grid) else { continue }
            var p = person
            let target: Spot?
            switch destination {
            case .outside: target = RoutePlanner.street(of: building, rules: rules)
            case let .room(r, x): target = world.rooms[r].map { Spot(floor: $0.floors.lowest, x: x) }
            }
            if let target, graph.isWalkable(position),
               let newLegs = RoutePlanner.plan(from: position, to: target, building: building, world: world,
                                               navigation: navigation, catalog: catalog, rules: rules, now: now),
               let last = newLegs.last {
                p.place = .travelling(legs: newLegs, destination: destination)
                p.nextEventTick = last.end
                report.replanned += 1
            } else {
                p.place = .outside
                p.unreachable = true
                p.nextGoal = nil
                if let schedule = rules.schedule(p.scheduleID) { scheduleNext(&p, after: now, schedule: schedule) }
                report.stranded += 1
            }
            world.people.update(p.id) { $0 = p }
        }
        return report
    }

    static func isValid(_ leg: Leg, in graph: NavigationGraph) -> Bool {
        switch leg {
        case let .walk(floor, fromX, toX, _, _):
            return graph.isWalkable(Spot(floor: floor, x: fromX)) && graph.isWalkable(Spot(floor: floor, x: toX))
        case let .stairs(shaft, f0, f1, leftX, _, _, _):
            guard let s = graph.shaft(shaft) else { return false }
            return s.leftX == leftX && s.floors.contains(min(f0, f1)) && s.floors.contains(max(f0, f1))
                && (min(f0, f1)...max(f0, f1)).allSatisfy { graph.isWalkable(Spot(floor: $0, x: leftX)) }
        }
    }

    /// Where a traveller stands at `now`, snapped to a floor (a stair climber steps onto the
    /// nearest landing of the storey they are on).
    private func currentSpot(_ legs: [Leg], at now: Tick, grid: GridSpec) -> Spot? {
        guard let sample = PersonMotion.sample(legs, at: Double(now), grid: grid) else { return nil }
        let leg = legs.first { now < $0.end } ?? legs.last!
        switch leg {
        case let .walk(floor, _, _, _, _):
            return Spot(floor: floor, x: sample.position.x)
        case let .stairs(_, _, _, leftX, _, _, _):
            return Spot(floor: Int((sample.position.y / grid.floorHeight).rounded()), x: leftX)
        }
    }
}
