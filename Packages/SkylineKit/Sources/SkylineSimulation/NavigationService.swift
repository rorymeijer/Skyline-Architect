import Foundation
import SkylineCore

/// Counters for the developer HUD and tests. Not simulation state; never saved.
public struct NavigationMetrics: Equatable, Sendable {
    public var queries = 0
    public var cacheHits = 0
    public var failures = 0
    public var graphBuilds = 0
    public var cachedRoutes = 0
    public var portals = 0
    public var edges = 0

    public init() {}

    public var hitRate: Double { queries == 0 ? 0 : Double(cacheHits) / Double(queries) }
}

/// Owns the per-building navigation graphs and a route cache.
///
/// The cache maps exact (from, to) spots to the portal sequence Dijkstra found, so a hit
/// yields exactly the route a fresh search would: results never depend on cache contents,
/// which keeps runs deterministic across save/load and batch sizes. People repeat the same
/// trips daily (their standing spots are personal and fixed), so hits dominate after day one.
/// A graph and its cache are dropped whenever the building's structure signature changes.
///
/// Shared by copies of `SimulationEngine`; internally synchronized.
public final class NavigationService: @unchecked Sendable {
    struct RouteKey: Hashable {
        var fromFloor: Int, fromX: UInt64, toFloor: Int, toX: UInt64, mode: RouteMode
    }

    struct BuildingNavigation {
        var graph: NavigationGraph
        var routes: [RouteKey: [Int]?] = [:]
        /// Elevator banks (Phase 19): they depend only on the shafts, which the structure
        /// signature covers, so they live and die with the graph.
        var banks: [ElevatorBank]?
    }

    /// Routes kept per building before the cache is cleared. Phase 19: 4096 thrashed at ~2,000
    /// people (29 % hits on a 400-floor tower); an entry is a short portal list (~100 B).
    public static let cacheLimit = 65_536

    private let lock = NSLock()
    private var buildings: [BuildingID: BuildingNavigation] = [:]
    private var counters = NavigationMetrics()

    public init() {}

    public var metrics: NavigationMetrics {
        lock.lock(); defer { lock.unlock() }
        var m = counters
        m.cachedRoutes = buildings.values.reduce(0) { $0 + $1.routes.count }
        m.portals = buildings.values.reduce(0) { $0 + $1.graph.portals.count }
        m.edges = buildings.values.reduce(0) { $0 + $1.graph.edgeCount }
        return m
    }

    /// The current graph for a building, rebuilt if its structure changed.
    public func graph(for building: Building, world: GameWorld, catalog: BuildCatalog, rules: SimulationRules) -> NavigationGraph {
        lock.lock(); defer { lock.unlock() }
        return current(building, world: world, catalog: catalog, rules: rules).graph
    }

    /// Drops graphs (and their cached routes) of buildings whose structure changed or that
    /// no longer exist. Called once per simulation step, so queries need no signature check.
    /// Returns whether anything was dropped (the structure changed since the last query).
    @discardableResult
    public func refresh(world: GameWorld, catalog: BuildCatalog) -> Bool {
        lock.lock(); defer { lock.unlock() }
        var changed = false
        for id in buildings.keys.sorted() {
            let building = world.buildings[id]
            if building.map({ NavigationGraph.signature(of: $0, world: world, catalog: catalog) }) != buildings[id]?.graph.signature {
                buildings[id] = nil
                changed = true
            }
        }
        return changed
    }

    /// Portal path between spots on different floors, or nil if unreachable. Same-floor trips
    /// never need the graph (every floor is one walking surface). Assumes `refresh` ran since
    /// the last structural change.
    func path(from: Spot, to: Spot, building: Building, world: GameWorld, catalog: BuildCatalog,
              rules: SimulationRules, mode: RouteMode = .public) -> (graph: NavigationGraph, portals: [Int])? {
        lock.lock(); defer { lock.unlock() }
        let graph = buildings[building.id]?.graph ?? build(building, world: world, catalog: catalog, rules: rules)
        counters.queries += 1
        let key = RouteKey(fromFloor: from.floor, fromX: from.x.bitPattern, toFloor: to.floor, toX: to.x.bitPattern, mode: mode)
        let found: [Int]?
        if let cached = buildings[building.id]?.routes[key] {
            counters.cacheHits += 1
            found = cached
        } else {
            found = graph.shortestPath(from: from, to: to, walkSpeed: rules.walkSpeed, mode: mode)
            if buildings[building.id]!.routes.count >= Self.cacheLimit {
                buildings[building.id]!.routes.removeAll(keepingCapacity: true)
            }
            buildings[building.id]!.routes[key] = .some(found)
        }
        guard let portals = found else {
            counters.failures += 1
            return nil
        }
        return (graph, portals)
    }

    /// The building's elevator banks, computed once per structure (`ElevatorBanks.banks`
    /// gives the same result). Strategies are player settings, read from the world each call.
    func banks(of building: Building, world: GameWorld, catalog: BuildCatalog, rules: SimulationRules) -> [ElevatorBank] {
        lock.lock(); defer { lock.unlock() }
        if buildings[building.id] == nil { _ = build(building, world: world, catalog: catalog, rules: rules) }
        let cars = world.elevators.values.reduce(0) { $0 + ($1.buildingID == building.id ? 1 : 0) }
        var banks: [ElevatorBank]
        if let cached = buildings[building.id]?.banks, cached.reduce(0, { $0 + $1.cars.count }) == cars {
            banks = cached
        } else {
            // Computed before the cars exist (or after they changed): recompute.
            banks = ElevatorBanks.banks(in: world, rules: rules, building: building.id)
            buildings[building.id]?.banks = banks
        }
        for i in banks.indices { banks[i].strategy = world.elevators[banks[i].id]?.strategy ?? banks[i].strategy }
        return banks
    }

    private func current(_ building: Building, world: GameWorld, catalog: BuildCatalog, rules: SimulationRules) -> BuildingNavigation {
        let signature = NavigationGraph.signature(of: building, world: world, catalog: catalog)
        if let nav = buildings[building.id], nav.graph.signature == signature { return nav }
        _ = build(building, world: world, catalog: catalog, rules: rules)
        return buildings[building.id]!
    }

    private func build(_ building: Building, world: GameWorld, catalog: BuildCatalog, rules: SimulationRules) -> NavigationGraph {
        let graph = NavigationGraph(building: building, world: world, catalog: catalog, rules: rules)
        buildings[building.id] = BuildingNavigation(graph: graph)
        counters.graphBuilds += 1
        return graph
    }
}
