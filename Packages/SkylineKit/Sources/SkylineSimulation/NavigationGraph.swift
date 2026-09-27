import Foundation
import SkylineCore

/// Walkable structure of one building, as a small graph over *portals*.
///
/// Two levels (SIMULATION.md §Navigation):
/// * **Floor level** — every floor plate is one contiguous walking surface (the ground floor
///   extends out to the street), so any two points on the same floor are connected by a
///   straight walk. Portals on a floor are chained in x order with walk edges.
/// * **Vertical level** — every vertical transport shaft contributes one portal per floor it
///   serves (at its landing) and an edge per storey between them. Stairs now; elevators
///   (Phase 6) add their own edge kind with waiting times.
///
/// A route is then: walk to a portal on the start floor, ride/climb, possibly walk across a
/// floor to another shaft (a *transfer*), … , walk to the target. The graph is immutable
/// and rebuilt only when the building's structure changes (`signature`).
public struct NavigationGraph: Sendable {
    public struct Portal: Hashable, Sendable {
        public var floor: Int
        public var x: Double
        public var shaft: RoomID
    }

    public enum EdgeKind: Hashable, Sendable {
        case walk
        case stairs(shaft: RoomID)
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
        // Portals: one per (stair shaft, served floor with a plate). Shafts in id order.
        for room in Self.transportRooms(of: building, world: world, catalog: catalog, kind: "stairs") {
            let leftX = grid.x(ofColumn: room.columns.start) + Self.stairLanding
            let rightX = grid.x(ofColumn: room.columns.end) - Self.stairLanding
            shafts[room.id] = StairShaft(id: room.id, floors: room.floors, leftX: leftX, rightX: rightX)
            var previous: Int?
            for floor in room.floors.lowest...room.floors.highest {
                guard walkable[floor] != nil else { previous = nil; continue }
                let index = portals.count
                portals.append(Portal(floor: floor, x: leftX, shaft: room.id))
                edges.append([])
                portalsByFloor[floor, default: []].append(index)
                if let p = previous {
                    let cost = Double(rules.stairsSecondsPerFloor)
                    edges[p].append(Edge(to: index, cost: cost, kind: .stairs(shaft: room.id)))
                    edges[index].append(Edge(to: p, cost: cost, kind: .stairs(shaft: room.id)))
                }
                previous = index
            }
        }
        // Walk edges: chain portals along each floor in x order (ties: index).
        for floor in portalsByFloor.keys {
            let sorted = portalsByFloor[floor]!.sorted { (portals[$0].x, $0) < (portals[$1].x, $1) }
            portalsByFloor[floor] = sorted
            for (a, b) in zip(sorted, sorted.dropFirst()) {
                let cost = abs(portals[b].x - portals[a].x) / rules.walkSpeed
                edges[a].append(Edge(to: b, cost: cost, kind: .walk))
                edges[b].append(Edge(to: a, cost: cost, kind: .walk))
            }
        }
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
    /// Deterministic Dijkstra: heap ordered by (cost, node index).
    func shortestPath(from: Spot, to: Spot, walkSpeed: Double) -> [Int]? {
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
