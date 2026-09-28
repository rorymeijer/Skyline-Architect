import Foundation
import SkylineCore

public struct ReplanReport: Equatable, Sendable {
    /// Travellers whose route used removed structure and got a new one.
    public var replanned = 0
    /// Travellers with no route left from where they were; they left the building.
    public var stranded = 0
}

extension SimulationEngine {
    /// Brings cars in line with the shafts, then re-plans trips invalidated by construction.
    /// A trip is invalid when a remaining leg walks where there is no floor, uses a stair
    /// shaft that no longer serves those floors, or waits for / rides an elevator that no
    /// longer serves the ride. Affected people continue from where they are now (people on
    /// stairs step onto the nearest landing; riders of a removed car step out at the floor it
    /// was nearest to); if no route remains they leave the building and are marked
    /// unreachable. Trips that are still valid are kept even if a faster route appeared.
    ///
    /// Runs automatically at the start of `advance` when the structure changed; the app also
    /// calls it right after a command so a paused game never shows people on removed stairs.
    @discardableResult
    public func replanAfterConstruction(_ world: inout GameWorld) -> ReplanReport {
        // Drop graphs and banks of changed structures first: the car sync reads banks.
        navigation.refresh(world: world, catalog: catalog)
        ElevatorSync.sync(&world, catalog: catalog, rules: rules)
        FacilitiesManagement.sync(&world)
        var report = ReplanReport()
        let now = world.clock.tick
        var graphs: [BuildingID: NavigationGraph] = [:]
        for person in world.people.values {
            guard let building = world.buildings[person.buildingID] else { continue }
            let graph = graphs[building.id] ?? navigation.graph(for: building, world: world, catalog: catalog, rules: rules)
            graphs[building.id] = graph
            let position: Spot?
            let destination: Destination
            switch person.place {
            case .outside, .room:
                continue
            case let .travelling(legs, d):
                let remaining = legs.filter { $0.end > now }
                let mode: RouteMode = person.role.isStaff ? .staff : .public
                let rideOK = person.pendingRide.map { graph.elevatorServes($0.shaft, $0.fromFloor, $0.toFloor, mode: mode) } ?? true
                guard !rideOK || !remaining.allSatisfy({ Self.isValid($0, in: graph) }) else { continue }
                position = currentSpot(legs, at: now, grid: world.grid)
                destination = d
            case let .waiting(ride, d, _):
                guard !(graph.elevatorServes(ride.shaft, ride.fromFloor, ride.toFloor) && world.elevators.contains(ride.shaft)) else { continue }
                position = Spot(floor: ride.fromFloor, x: ride.x)
                destination = d
            case .riding:
                continue                      // cars of removed shafts were emptied by the sync
            }
            var p = person
            if let position, graph.isWalkable(position),
               startTrip(&p, from: position, to: destination, building: building, world: world, now: now) {
                report.replanned += 1
            } else {
                strand(&p, at: now)
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
    func currentSpot(_ legs: [Leg], at now: Tick, grid: GridSpec) -> Spot? {
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
