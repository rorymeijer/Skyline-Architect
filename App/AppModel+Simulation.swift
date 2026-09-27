import Foundation
import SkylineCore
import SkylineSimulation

extension AppModel {
    // MARK: Simulation

    /// Called every rendered frame: runs as many fixed ticks as the speed demands.
    func stepSimulation(realDelta: Double) {
        let ticks = host.ticksToRun(realDelta: realDelta)
        guard ticks > 0 else { return }
        advanceSimulation(ticks: ticks)
    }

    /// Runs exactly `ticks` simulation ticks (also used by captures and tests).
    func advanceSimulation(ticks: Tick) {
        guard var w = world, let simulation else { return }
        let start = Date()
        simulation.advance(&w, by: ticks)
        lastSimulationMs = Date().timeIntervalSince(start) * 1000
        world = w
        hasUnsavedChanges = true
    }

    /// Advances to the next occurrence of a time of day (captures, developer tools).
    func advanceSimulation(toTimeOfDay hour: Int, minute: Int = 0) {
        guard let tick = world?.clock.tick else { return }
        let target = SimClock.nextTick(atSecondOfDay: Tick(hour * 3600 + minute * 60), onOrAfter: tick)
        advanceSimulation(ticks: target - tick)
    }

    /// Looks ahead on a copy of the world (the real world is untouched) and returns how many
    /// ticks from now the `score` is highest within `window`, sampling every `step` ticks.
    /// Used by automated captures to find moments with activity.
    func ticksToBestMoment(within window: Tick, step: Tick, score: (GameWorld) -> Int) -> Tick {
        guard var copy = world, let simulation else { return 0 }
        var best: (ticks: Tick, score: Int) = (0, score(copy))
        var elapsed: Tick = 0
        while elapsed + step <= window {
            simulation.advance(&copy, by: step)
            elapsed += step
            let s = score(copy)
            if s > best.score { best = (elapsed, s) }
        }
        return best.ticks
    }

    func setSpeed(_ s: GameSpeed) {
        host.speed = s
        speed = s
        if s != .paused { speedBeforePause = s }
    }

    func togglePause() { setSpeed(speed == .paused ? speedBeforePause : .paused) }

    func refreshSimulationSummary() {
        guard let world else { return }
        let tick = world.clock.tick
        clockText = "Day \(SimClock.day(tick) + 1) · \(SimClock.timeString(tick))"
        population = PopulationSummary(world)
        if let simulation { navigationMetrics = simulation.navigation.metrics }
        banks = traffic()?.banks ?? []
        refreshLeasing()
        refreshEconomy()
    }

    // MARK: Elevator banks

    /// Traffic of the active property's buildings at the current (fractional) time.
    func traffic() -> ElevatorTraffic? {
        guard let world, let property = activePropertyID, let simulation else { return nil }
        return ElevatorTraffic.make(world: world, rules: simulation.rules, buildings: world.buildings(on: property).map(\.id),
                                    now: world.clock.tick)
    }

    func setStrategy(_ strategy: DispatchStrategy, bank: RoomID) {
        guard var w = world, let simulation else { return }
        ElevatorBanks.setStrategy(strategy, bank: bank, in: &w, rules: simulation.rules)
        world = w
        hasUnsavedChanges = true
        refreshSimulationSummary()
    }

    /// Door open/close time of a shaft's cars (content), for rendering.
    func doorSeconds(of shaft: RoomID) -> Double {
        guard let world, let room = world.rooms[shaft], let spec = simulation?.rules.elevator(for: room.definitionID) else { return 2 }
        return Double(spec.doorSeconds)
    }

    // MARK: Navigation overlay (developer)

    func toggleNavigationOverlay() { showNavigationOverlay.toggle() }

    /// Graph and active routes of the buildings on the active property, or nil when hidden.
    func navigationOverlay() -> NavigationOverlay? {
        guard showNavigationOverlay, let world, let property = activePropertyID, let simulation else { return nil }
        var merged = NavigationOverlay()
        for building in world.buildings(on: property) {
            let graph = simulation.navigation.graph(for: building, world: world, catalog: simulation.catalog, rules: simulation.rules)
            let o = NavigationOverlay.make(graph: graph, world: world, now: Double(world.clock.tick) + host.fraction)
            merged.walkLinks += o.walkLinks
            merged.stairLinks += o.stairLinks
            merged.elevatorLinks += o.elevatorLinks
            merged.portals += o.portals
            merged.routes += o.routes
        }
        return merged
    }
}

/// Counts shown in the UI and HUD.
struct PopulationSummary: Equatable {
    var total = 0
    var inRooms = 0
    var travelling = 0
    var outside = 0
    var unreachable = 0
    var waiting = 0
    var riding = 0
    var cars = 0
    /// Longest current wait at any landing, seconds.
    var longestWait: Tick = 0

    init() {}

    init(_ world: GameWorld) {
        cars = world.elevators.count
        for p in world.people {
            total += 1
            if p.unreachable { unreachable += 1 }
            switch p.place {
            case .outside: outside += 1
            case .room: inRooms += 1
            case .travelling: travelling += 1
            case let .waiting(_, _, since):
                travelling += 1
                waiting += 1
                longestWait = max(longestWait, world.clock.tick - since)
            case .riding:
                travelling += 1
                riding += 1
            }
        }
    }
}
