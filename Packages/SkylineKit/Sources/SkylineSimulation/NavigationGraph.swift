import Foundation
import SkylineCore

/// Which vertical transport a route may use.
public enum RouteMode: Hashable, Sendable {
    /// Stairs and public elevators (tenants).
    case `public`
    /// Stairs only (someone who gave up on a queue).
    case stairsOnly
    /// Stairs and all elevators including service elevators (building staff).
    case staff
}

/// Walkable structure of one building, as a small graph over *portals*.
///
/// Two levels (SIMULATION.md §Navigation):
/// * **Floor level** — every floor plate is one contiguous walking surface (the ground floor
///   extends out to the street), so any two points on the same floor are connected by a
///   straight walk. Portals on a floor are chained in x order with walk edges.
/// * **Vertical level** — every stair shaft contributes one portal per floor it serves (at its
///   landing) and an edge per storey between them. Every elevator shaft contributes a landing
///   portal and an in-car node per served floor: boarding (landing → car) costs the expected
///   wait plus door time, riding costs travel time per storey, alighting costs the transfer.
///
/// A route is then: walk to a portal on the start floor, ride/climb, possibly walk across a
/// floor to another shaft (a *transfer*), … , walk to the target. The graph is immutable
/// and rebuilt only when the building's structure changes (`signature`).
public struct NavigationGraph: Sendable {
    public enum PortalKind: Hashable, Sendable {
        case stairLanding, elevatorLanding, elevatorCar
    }

    public struct Portal: Hashable, Sendable {
        public var floor: Int
        public var x: Double
        public var shaft: RoomID
        public var kind: PortalKind
    }

    public enum EdgeKind: Hashable, Sendable {
        case walk
        case stairs(shaft: RoomID)
        case board(shaft: RoomID)
        case ride(shaft: RoomID)
        case alight(shaft: RoomID)
    }

    public struct Edge: Hashable, Sendable {
        public var to: Int
        public var cost: Double
        public var kind: EdgeKind
    }

    /// Geometry of one stair shaft: flights run between `leftX` and `rightX`.
    struct StairShaft: Sendable {
        var id: RoomID
        var floors: FloorSpan
        var leftX: Double
        var rightX: Double
    }

    public let buildingID: BuildingID
    public let signature: UInt64
    public private(set) var portals: [Portal] = []
    public private(set) var edges: [[Edge]] = []
    /// Walkable x interval per floor (the plate; floor 0 extends to the street).
    private(set) var walkable: [Int: ClosedRange<Double>] = [:]
    private(set) var portalsByFloor: [Int: [Int]] = [:]
    private(set) var shafts: [RoomID: StairShaft] = [:]
    /// Elevator shafts only staff may use (service elevators, Phase 10).
    private(set) var serviceShafts = Set<RoomID>()
    /// Floors where cars stop, and landing x, of each elevator shaft.
    private(set) var elevatorShafts: [RoomID: (served: Set<Int>, x: Double)] = [:]

    public static let stairLanding = 1.1

    public var edgeCount: Int { edges.reduce(0) { $0 + $1.count } }

    init(building: Building, world: GameWorld, catalog: BuildCatalog, rules: SimulationRules) {
        buildingID = building.id
        signature = Self.signature(of: building, world: world, catalog: catalog)
        let grid = world.grid
        for plate in building.floors {
            var lo = grid.x(ofColumn: plate.span.start), hi = grid.x(ofColumn: plate.span.end)
            if plate.level == 0, let street = RoutePlanner.street(of: building, rules: rules) { lo = min(lo, street.x) }
            walkable[plate.level] = lo...hi
        }
        func addPortal(_ portal: Portal, walkable onFloor: Bool) -> Int {
            portals.append(portal)
            edges.append([])
            if onFloor { portalsByFloor[portal.floor, default: []].append(portals.count - 1) }
            return portals.count - 1
        }
        func link(_ a: Int, _ b: Int, _ cost: Double, _ kind: EdgeKind) {
            edges[a].append(Edge(to: b, cost: cost, kind: kind))
        }
        // Stairs: one portal per (shaft, served floor with a plate). Shafts in id order.
        for room in Self.transportRooms(of: building, world: world, catalog: catalog, kind: "stairs") {
            let leftX = grid.x(ofColumn: room.columns.start) + Self.stairLanding
            let rightX = grid.x(ofColumn: room.columns.end) - Self.stairLanding
            shafts[room.id] = StairShaft(id: room.id, floors: room.floors, leftX: leftX, rightX: rightX)
            var previous: Int?
            for floor in room.floors.lowest...room.floors.highest {
                guard walkable[floor] != nil else { previous = nil; continue }
                let index = addPortal(Portal(floor: floor, x: leftX, shaft: room.id, kind: .stairLanding), walkable: true)
                if let p = previous {
                    let cost = Double(rules.stairsSecondsPerFloor)
                    link(p, index, cost, .stairs(shaft: room.id))
                    link(index, p, cost, .stairs(shaft: room.id))
                }
                previous = index
            }
        }
        // Elevators: landing + car node per served floor; rides chain the car nodes.
        for room in Self.transportRooms(of: building, world: world, catalog: catalog, kind: "elevator") {
            guard let spec = rules.elevator(for: room.definitionID) else { continue }
            let x = Self.elevatorLandingX(room, grid: grid)
            let served = Set(spec.servedFloors(of: room.floors))
            elevatorShafts[room.id] = (served, x)
            if spec.serviceOnly == true { serviceShafts.insert(room.id) }
            let perFloor = grid.floorHeight / spec.speed
            let boarding = spec.expectedWaitSeconds + Double(2 * spec.doorSeconds + spec.transferSeconds) + spec.speed / spec.acceleration
            var previousCar: Int?
            for floor in room.floors.lowest...room.floors.highest {
                let car = addPortal(Portal(floor: floor, x: x, shaft: room.id, kind: .elevatorCar), walkable: false)
                if let p = previousCar {
                    link(p, car, perFloor, .ride(shaft: room.id))
                    link(car, p, perFloor, .ride(shaft: room.id))
                }
                previousCar = car
                guard walkable[floor] != nil, served.contains(floor) else { continue }
                let landing = addPortal(Portal(floor: floor, x: x, shaft: room.id, kind: .elevatorLanding), walkable: true)
                link(landing, car, boarding, .board(shaft: room.id))
                link(car, landing, Double(spec.transferSeconds), .alight(shaft: room.id))
            }
        }
        // Walk edges: chain landings along each floor in x order (ties: index).
        for floor in portalsByFloor.keys.sorted() {
            let sorted = portalsByFloor[floor]!.sorted { (portals[$0].x, $0) < (portals[$1].x, $1) }
            portalsByFloor[floor] = sorted
            for (a, b) in zip(sorted, sorted.dropFirst()) {
                let cost = abs(portals[b].x - portals[a].x) / rules.walkSpeed
                link(a, b, cost, .walk)
                link(b, a, cost, .walk)
            }
        }
    }

    /// Where people wait for an elevator: in front of the shaft's centre.
    static func elevatorLandingX(_ room: Room, grid: GridSpec) -> Double {
        (grid.x(ofColumn: room.columns.start) + grid.x(ofColumn: room.columns.end)) / 2
    }

    /// Whether the elevator shaft `id` exists and serves both floors.
    func elevatorServes(_ id: RoomID, _ a: Int, _ b: Int, mode: RouteMode = .staff) -> Bool {
        if mode == .public && serviceShafts.contains(id) { return false }
        return elevatorShafts[id].map { $0.served.contains(a) && $0.served.contains(b) } ?? false
    }

    /// Whether `spot` is on a walking surface of this building.
    func isWalkable(_ spot: Spot) -> Bool {
        walkable[spot.floor].map { $0.contains(spot.x) } ?? false
    }

    func shaft(_ id: RoomID) -> StairShaft? { shafts[id] }

    /// Rooms acting as vertical transport of `kind` in a building, in id order.
    static func transportRooms(of building: Building, world: GameWorld, catalog: BuildCatalog, kind: String) -> [Room] {
        world.rooms(in: building.id).filter { catalog.spec($0.definitionID)?.transport == kind }
    }

    /// Hash of everything that shapes the graph: plates and transport shafts. Cheap enough
    /// to evaluate once per simulation step; equal signatures mean an identical graph.
    static func signature(of building: Building, world: GameWorld, catalog: BuildCatalog) -> UInt64 {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        func mix(_ v: Int) {
            h ^= UInt64(bitPattern: Int64(v))
            h = h &* 0x100_0000_01b3
        }
        for plate in building.floors { mix(plate.level); mix(plate.span.start); mix(plate.span.count) }
        mix(-1)
        for room in world.rooms(in: building.id) where catalog.spec(room.definitionID)?.transport != nil {
            mix(Int(room.id.raw)); mix(room.columns.start); mix(room.columns.count)
            mix(room.floors.lowest); mix(room.floors.highest)
        }
        return h
    }
}

// MARK: - Shortest paths

extension NavigationGraph {
    /// Portal sequence of the fastest route from `from` to `to` (different floors), or nil.
    /// `mode` restricts which elevators may be boarded (stairs only, public, or staff).
    /// Deterministic Dijkstra: heap ordered by (cost, node index).
    func shortestPath(from: Spot, to: Spot, walkSpeed: Double, mode: RouteMode = .public) -> [Int]? {
        guard let starts = portalsByFloor[from.floor], let ends = portalsByFloor[to.floor] else { return nil }
        let target = portals.count          // virtual target node
        var dist = [Double](repeating: .infinity, count: portals.count + 1)
        var previous = [Int](repeating: -1, count: portals.count + 1)
        var heap = MinHeap<(Double, Int)> { $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0 }
        for s in starts {
            dist[s] = abs(portals[s].x - from.x) / walkSpeed
            heap.push((dist[s], s))
        }
        let endCost = Dictionary(uniqueKeysWithValues: ends.map { ($0, abs(portals[$0].x - to.x) / walkSpeed) })
        while let (d, node) = heap.popMin() {
            guard d == dist[node] else { continue }
            if node == target { break }
            if let c = endCost[node], d + c < dist[target] || (d + c == dist[target] && node < previous[target]) {
                dist[target] = d + c
                previous[target] = node
                heap.push((d + c, target))
            }
            for edge in edges[node] where d + edge.cost < dist[edge.to] {
                if case let .board(shaft) = edge.kind {
                    if mode == .stairsOnly || (mode == .public && serviceShafts.contains(shaft)) { continue }
                }
                dist[edge.to] = d + edge.cost
                previous[edge.to] = node
                heap.push((dist[edge.to], edge.to))
            }
        }
        guard previous[target] >= 0 else { return nil }
        var path: [Int] = []
        var node = previous[target]
        while node >= 0 {
            path.append(node)
            node = previous[node]
        }
        return path.reversed()
    }
}
