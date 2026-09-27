import Foundation
import SkylineCore

public struct SimulationReport: Equatable, Sendable {
    public var ticks: Tick = 0
    public var eventsProcessed = 0
    public var unreachable = 0
}

/// Advances the world in whole ticks, processing person events in (tick, id) order.
///
/// Event-driven: people are only touched when something happens to them (arrival, next
/// schedule event); movement between events is analytic (`PersonMotion`). The event queue
/// is rebuilt per call from `nextEventTick`, so it is never stale and never saved. The result
/// after N ticks is identical however the N ticks are batched (tested).
public struct SimulationEngine: Sendable {
    public let rules: SimulationRules
    public let catalog: BuildCatalog

    public init(rules: SimulationRules, catalog: BuildCatalog) {
        self.rules = rules
        self.catalog = catalog
    }

    @discardableResult
    public func advance(_ world: inout GameWorld, by ticks: Tick) -> SimulationReport {
        var report = SimulationReport(ticks: ticks)
        let target = world.clock.tick + ticks
        var queue = EventQueue(world.people.values.filter { $0.nextEventTick <= target }.map { ($0.nextEventTick, $0.id) })
        while let (tick, id) = queue.popMin() {
            guard var person = world.people[id], person.nextEventTick == tick else { continue }
            world.clock.tick = max(world.clock.tick, tick)
            handle(&person, at: tick, world: world, report: &report)
            report.eventsProcessed += 1
            world.people.update(id) { $0 = person }
            if person.nextEventTick <= target && person.nextEventTick > tick { queue.push((person.nextEventTick, id)) }
        }
        world.clock.tick = target
        return report
    }

    private func handle(_ p: inout Person, at now: Tick, world: GameWorld, report: inout SimulationReport) {
        guard let building = world.buildings[p.buildingID], let schedule = rules.schedule(p.scheduleID) else {
            p.nextEventTick = now + SimClock.secondsPerDay
            return
        }
        // Arrival at the end of a trip.
        if case let .travelling(_, destination) = p.place {
            switch destination {
            case .outside: p.place = .outside
            case let .room(r, x): p.place = world.rooms.contains(r) ? .room(r, x: x) : .outside
            }
            scheduleNext(&p, after: now, schedule: schedule)
            return
        }
        guard let goal = p.nextGoal else {
            scheduleNext(&p, after: now, schedule: schedule)
            return
        }
        // Resolve the goal to a destination.
        let destination: Destination
        let target: Spot
        switch goal {
        case .outside:
            guard let street = RoutePlanner.street(of: building, rules: rules) else { return scheduleNext(&p, after: now, schedule: schedule) }
            destination = .outside
            target = street
        case .work, .home:
            guard let roomID = goal == .work ? p.workRoom : p.homeRoom, let room = world.rooms[roomID] else {
                return scheduleNext(&p, after: now, schedule: schedule)
            }
            target = RoutePlanner.standingSpot(in: room, traits: p.traits, grid: world.grid)
            destination = .room(roomID, x: target.x)
        }
        // Where are they now?
        let origin: Spot?
        switch p.place {
        case .outside:
            if destination == .outside { return scheduleNext(&p, after: now, schedule: schedule) }
            origin = RoutePlanner.street(of: building, rules: rules)
        case let .room(r, x):
            if case let .room(dr, _) = destination, dr == r { return scheduleNext(&p, after: now, schedule: schedule) }
            origin = world.rooms[r].map { Spot(floor: $0.floors.lowest, x: x) }
        case .travelling:
            origin = nil
        }
        guard let from = origin,
              let legs = RoutePlanner.plan(from: from, to: target, building: building, world: world, catalog: catalog, rules: rules, now: now),
              let last = legs.last else {
            p.unreachable = true
            report.unreachable += 1
            return scheduleNext(&p, after: now, schedule: schedule)
        }
        p.unreachable = false
        p.place = .travelling(legs: legs, destination: destination)
        p.nextGoal = nil
        p.nextEventTick = last.end
    }

    private func scheduleNext(_ p: inout Person, after now: Tick, schedule: Schedule) {
        if let next = rules.nextScheduled(after: now, schedule: schedule, traits: p.traits) {
            p.nextGoal = next.goal
            p.nextEventTick = next.tick
        } else {
            p.nextGoal = nil
            p.nextEventTick = now + SimClock.secondsPerDay
        }
    }
}

/// Binary min-heap of (tick, person id); ties broken by id for determinism.
struct EventQueue {
    private var heap: [(Tick, PersonID)] = []

    init(_ items: [(Tick, PersonID)]) {
        for item in items { push(item) }
    }

    private static func less(_ a: (Tick, PersonID), _ b: (Tick, PersonID)) -> Bool {
        a.0 == b.0 ? a.1 < b.1 : a.0 < b.0
    }

    mutating func push(_ item: (Tick, PersonID)) {
        heap.append(item)
        var i = heap.count - 1
        while i > 0 {
            let parent = (i - 1) / 2
            guard Self.less(heap[i], heap[parent]) else { break }
            heap.swapAt(i, parent)
            i = parent
        }
    }

    mutating func popMin() -> (Tick, PersonID)? {
        guard !heap.isEmpty else { return nil }
        heap.swapAt(0, heap.count - 1)
        let min = heap.removeLast()
        var i = 0
        while true {
            let l = 2 * i + 1, r = l + 1
            var smallest = i
            if l < heap.count, Self.less(heap[l], heap[smallest]) { smallest = l }
            if r < heap.count, Self.less(heap[r], heap[smallest]) { smallest = r }
            if smallest == i { break }
            heap.swapAt(i, smallest)
            i = smallest
        }
        return min
    }
}
