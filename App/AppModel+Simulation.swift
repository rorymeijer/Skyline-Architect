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
    }
}

/// Counts shown in the UI and HUD.
struct PopulationSummary: Equatable {
    var total = 0
    var inRooms = 0
    var travelling = 0
    var outside = 0
    var unreachable = 0

    init() {}

    init(_ world: GameWorld) {
        for p in world.people {
            total += 1
            if p.unreachable { unreachable += 1 }
            switch p.place {
            case .outside: outside += 1
            case .room: inRooms += 1
            case .travelling: travelling += 1
            }
        }
    }
}
