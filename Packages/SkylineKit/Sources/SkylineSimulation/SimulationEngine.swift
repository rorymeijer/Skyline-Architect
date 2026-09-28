import Foundation
import SkylineCore

public struct SimulationReport: Equatable, Sendable {
    public var ticks: Tick = 0
    public var eventsProcessed = 0
    public var unreachable = 0
}

/// Who an event belongs to. At equal ticks the market acts first, then cars, then people
/// (then by id), so a car
/// arriving and a person arriving at the same tick resolve in a fixed order.
enum EventTarget: Comparable {
    case market
    /// Fires in progress (Phase 14), all stepped together.
    case fires
    case car(RoomID)
    case person(PersonID)
}

/// Advances the world in whole ticks, processing car and person events in (tick, target)
/// order.
///
/// Event-driven: people are only touched when something happens to them (arrival, next
/// schedule event), cars when they arrive or their doors close; movement between events is
/// analytic (`PersonMotion`, `ElevatorMotion`). The event queue is rebuilt per call from
/// `nextEventTick`, so it is never stale and never saved. The result after N ticks is
/// identical however the N ticks are batched (tested).
public struct SimulationEngine: Sendable {
    public let rules: SimulationRules
    public let catalog: BuildCatalog
    /// Graphs and route cache; shared by copies of this engine (a cache, never state).
    public let navigation: NavigationService

    public init(rules: SimulationRules, catalog: BuildCatalog, navigation: NavigationService = NavigationService()) {
        self.rules = rules
        self.catalog = catalog
        self.navigation = navigation
    }

    /// Pending events of one `advance` call.
    struct Events {
        let target: Tick
        var heap = MinHeap<(Tick, EventTarget)> { $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0 }

        mutating func push(_ tick: Tick, _ who: EventTarget) {
            if tick <= target { heap.push((tick, who)) }
        }
    }

    @discardableResult
    public func advance(_ world: inout GameWorld, by ticks: Tick) -> SimulationReport {
        var report = SimulationReport(ticks: ticks)
        var events = Events(target: world.clock.tick + ticks)
        if navigation.refresh(world: world, catalog: catalog) || !ElevatorSync.isInSync(world, catalog: catalog, rules: rules)
            || !FacilitiesManagement.isInSync(world) {
            replanAfterConstruction(&world)
        }
        startWeatherIfNeeded(&world)
        if !rules.tenantTypes.isEmpty { events.push(world.market.nextTick, .market) }
        if let next = world.incidents.fires.map(\.nextStep).min() { events.push(next, .fires) }
        for car in world.elevators { events.push(car.nextEventTick, .car(car.id)) }
        for p in world.people { events.push(p.nextEventTick, .person(p.id)) }
        while let (tick, who) = events.heap.popMin() {
            world.clock.tick = max(world.clock.tick, tick)
            switch who {
            case .market:
                guard world.market.nextTick == tick else { continue }
                for id in runMarket(at: tick, world: &world) { events.push(world.people[id]!.nextEventTick, .person(id)) }
                checkWeatherIncidents(at: tick, world: &world)
                checkIgnition(at: tick, world: &world, events: &events)
                events.push(world.market.nextTick, .market)
            case .fires:
                guard world.incidents.fires.contains(where: { $0.nextStep == tick }) else { continue }
                stepFires(at: tick, world: &world, events: &events)
            case let .car(id):
                guard world.elevators[id]?.nextEventTick == tick else { continue }
                handleCar(id, at: tick, world: &world, events: &events, report: &report)
            case let .person(id):
                guard var person = world.people[id], person.nextEventTick == tick else { continue }
                if world.incidents.isOnFire(person.buildingID), !person.isQueuing {
                    handleDuringFire(id, at: tick, world: &world, events: &events)
                    report.eventsProcessed += 1
                    continue
                }
                if person.role.isStaff, !person.isQueuing {
                    handleStaff(id, at: tick, world: &world, events: &events)
                    report.eventsProcessed += 1
                    continue
                }
                let outcome = handle(&person, at: tick, world: world, report: &report)
                world.people.update(id) { $0 = person }
                if person.nextEventTick > tick { events.push(person.nextEventTick, .person(id)) }
                switch outcome {
                case let .joinedQueue(car): wakeCar(car, at: tick, world: &world, events: &events)
                case let .abandoned(car): world.elevators.update(car) { $0.stats.abandoned += 1 }
                case .none: break
                }
            }
            report.eventsProcessed += 1
        }
        world.clock.tick = events.target
        return report
    }

    /// What a person event did that concerns a car.
    enum Outcome {
        case none
        case joinedQueue(RoomID)
        case abandoned(RoomID)
    }

    private func handle(_ p: inout Person, at now: Tick, world: GameWorld, report: inout SimulationReport) -> Outcome {
        guard let building = world.buildings[p.buildingID] else {
            p.nextEventTick = now + SimClock.secondsPerDay
            return .none
        }
        // Elevator mechanics first: they apply to everyone, with or without a schedule (staff).
        // End of the walking part of a trip: the bank assigns a car (walk over to its doors
        // if it is another shaft), then queue; or arrive.
        if case let .travelling(_, destination) = p.place {
            if let ride = p.pendingRide {
                if ride.assigned != true {
                    let assigned = assign(ride, world: world, now: now)
                    if abs(assigned.x - ride.x) > 0.01 {
                        let d = max(Tick((abs(assigned.x - ride.x) / rules.walkSpeed).rounded(.up)), 1)
                        p.place = .travelling(legs: [.walk(floor: ride.fromFloor, fromX: ride.x, toX: assigned.x, start: now, end: now + d)],
                                              destination: destination)
                        p.pendingRide = assigned
                        p.nextEventTick = now + d
                        return .none
                    }
                    return joinQueue(&p, assigned, destination, at: now, world: world)
                }
                return joinQueue(&p, ride, destination, at: now, world: world)
            }
            guard let schedule = rules.schedule(p.scheduleID) else { p.nextEventTick = now + 900; return .none }
            switch destination {
            case .outside: p.place = .outside
            case let .room(r, x): p.place = world.rooms.contains(r) ? .room(r, x: x) : .outside
            }
            scheduleNext(&p, after: now, schedule: schedule)
            return .none
        }
        // Patience ran out at a landing: take the stairs if that is a reasonable walk.
        if case let .waiting(ride, destination, _) = p.place {
            var q = p
            if startTrip(&q, from: Spot(floor: ride.fromFloor, x: ride.x), to: destination, building: building,
                         world: world, now: now, stairsOnly: true),
               q.nextEventTick - now <= rules.maxStairsDetourSeconds {
                p = q
                return .abandoned(ride.shaft)
            }
            p.nextEventTick = .max                     // no sensible alternative: keep waiting
            return .none
        }
        guard let schedule = rules.schedule(p.scheduleID) else {
            p.nextEventTick = now + SimClock.secondsPerDay
            return .none
        }
        guard let goal = p.nextGoal else {
            scheduleNext(&p, after: now, schedule: schedule)
            return .none
        }
        // Resolve the goal to a destination.
        let destination: Destination
        switch goal {
        case .outside:
            destination = .outside
        case .work, .home:
            guard let roomID = goal == .work ? p.workRoom : p.homeRoom, let room = world.rooms[roomID] else {
                scheduleNext(&p, after: now, schedule: schedule)
                return .none
            }
            destination = .room(roomID, x: RoutePlanner.standingSpot(in: room, traits: p.traits, grid: world.grid).x)
        }
        // Where are they now?
        let origin: Spot?
        switch p.place {
        case .outside:
            if destination == .outside { scheduleNext(&p, after: now, schedule: schedule); return .none }
            origin = RoutePlanner.street(of: building, rules: rules)
        case let .room(r, x):
            if case let .room(dr, _) = destination, dr == r { scheduleNext(&p, after: now, schedule: schedule); return .none }
            origin = world.rooms[r].map { Spot(floor: $0.floors.lowest, x: x) }
        case .travelling, .waiting, .riding:
            origin = nil
        }
        guard let from = origin, startTrip(&p, from: from, to: destination, building: building, world: world, now: now) else {
            p.unreachable = true
            report.unreachable += 1
            scheduleNext(&p, after: now, schedule: schedule)
            return .none
        }
        return .none
    }

    /// Queue at the assigned car's landing; patience runs from now.
    private func joinQueue(_ p: inout Person, _ ride: Ride, _ destination: Destination, at now: Tick, world: GameWorld) -> Outcome {
        p.pendingRide = nil
        p.place = .waiting(ride, destination: destination, since: now)
        let spec = world.rooms[ride.shaft].flatMap { rules.elevator(for: $0.definitionID) }
        p.nextEventTick = now + (spec?.patience(traits: p.traits) ?? 150)
        return .joinedQueue(ride.shaft)
    }

    /// Where a destination is on the building's walking surfaces.
    func spot(of destination: Destination, building: Building, world: GameWorld) -> Spot? {
        switch destination {
        case .outside: RoutePlanner.street(of: building, rules: rules)
        case let .room(r, x): world.rooms[r].map { Spot(floor: $0.floors.lowest, x: x) }
        }
    }

    /// Plans and starts a trip (the walking part, plus a pending ride if the route uses an
    /// elevator). Returns false if there is no route; `p` is then unchanged.
    /// `stairsOnly` excludes all elevators; otherwise staff may use service elevators too.
    func startTrip(_ p: inout Person, from: Spot, to destination: Destination, building: Building,
                   world: GameWorld, now: Tick, stairsOnly: Bool = false) -> Bool {
        let mode: RouteMode = stairsOnly ? .stairsOnly : p.role.isStaff ? .staff : .public
        guard let target = spot(of: destination, building: building, world: world),
              let trip = RoutePlanner.plan(from: from, to: target, building: building, world: world, navigation: navigation,
                                           catalog: catalog, rules: rules, now: now, mode: mode),
              let last = trip.legs.last else { return false }
        p.unreachable = false
        p.place = .travelling(legs: trip.legs, destination: destination)
        p.pendingRide = trip.ride
        p.nextGoal = nil
        p.nextEventTick = last.end
        return true
    }

    func scheduleNext(_ p: inout Person, after now: Tick, schedule: Schedule) {
        if let next = rules.nextScheduled(after: now, schedule: schedule, traits: p.traits) {
            p.nextGoal = next.goal
            p.nextEventTick = next.tick
        } else {
            p.nextGoal = nil
            p.nextEventTick = now + SimClock.secondsPerDay
        }
    }

    /// Someone with no way to continue leaves the building and resumes their schedule.
    func strand(_ p: inout Person, at now: Tick) {
        p.place = .outside
        p.pendingRide = nil
        p.unreachable = true
        p.nextGoal = nil
        if let schedule = rules.schedule(p.scheduleID) {
            scheduleNext(&p, after: now, schedule: schedule)
        } else {
            p.nextEventTick = now + 900                     // staff: look for work again later
        }
    }
}
