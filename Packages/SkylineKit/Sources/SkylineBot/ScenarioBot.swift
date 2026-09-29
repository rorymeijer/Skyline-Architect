import Foundation
import SkylineCore
import SkylineContent
import SkylineSimulation

/// What one bot play of a scenario came to (F1). See Documentation/BALANCE.md.
public struct BotReport: Sendable {
    public var scenarioID: String
    public var name: String
    public var result: ScenarioResult?
    /// Days the scenario ran (to the decision, or to the end of the run).
    public var days: Int
    /// Objective labels with the last measured value.
    public var objectives: [(label: String, value: String, met: Bool)]
    public var floors: Int
    public var population: Int
    public var units: Int
    public var minCash: Int
    public var finalCash: Int
    public var loans: Int
    /// Rentable units built, and the market: prospects, signed, moved out, declines by reason.
    public var unitsBuilt: Int
    public var market: String
    /// Notable moments, one line each ("D3 class B", "D8 blocked: needs Class A").
    public var log: [String]
}

/// A simple, honest player for balancing (F1). Every morning after the closing it looks at
/// its cash and builds through the construction engine exactly as the app does (commands
/// charged by `ConstructionHistory`); leasing, visitors and everything else is left to the
/// simulation. No developer grants, no instant leasing. A bot win proves a scenario can be
/// won; a bot loss marks it as hard (or too hard) for a closer look.
public struct ScenarioBot {
    public let library: ContentLibrary
    let engine: SimulationEngine
    let construction: ConstructionEngine
    var history = ConstructionHistory()
    var log: [String] = []

    /// Floors built per morning at most, and the cash kept back for the running costs.
    public var floorsPerDay = 3
    public var reserve = 250_000

    public init(library: ContentLibrary) {
        self.library = library
        engine = SimulationEngine(rules: library.simulationRules, catalog: library.buildCatalog)
        construction = ConstructionEngine(catalog: library.buildCatalog)
    }

    /// Plays a scenario to its decision (or `maxDays`) and reports.
    public mutating func play(_ scenarioID: String, maxDays: Int? = nil) throws -> BotReport {
        var game = try NewGameFactory.make(scenarioID: scenarioID, library: library)
        guard let def = library.scenario(scenarioID), let building = game.world.buildings(on: game.activePropertyID).first else {
            throw ContentError(pack: library.manifest.id, file: "scenarios", message: "Unknown scenario '\(scenarioID)'")
        }
        let plan = TowerPlan(building: building)
        var world = game.world
        log = []
        var minCash = world.ledger.cash
        setUp(plan, world: &world)
        let limit = maxDays ?? def.days + 1
        for _ in 0..<limit {
            engine.advance(&world, by: SimClock.nextTick(atSecondOfDay: 7 * 3600, onOrAfter: world.clock.tick + 1) - world.clock.tick)
            minCash = min(minCash, world.ledger.cash)
            if world.scenario?.result != nil { break }
            morning(plan, def: def, world: &world)
        }
        let s = world.scenario
        let measured = Scenarios.measured(world: world, engine: engine)
        return BotReport(
            scenarioID: scenarioID, name: def.name, result: s?.result,
            days: Int(SimClock.day(s?.result?.tick ?? world.clock.tick)) - Int(s?.startDay ?? 0),
            objectives: zip(def.objectives, measured).map { o, v in
                (ScenarioSummary.label(o, library: library), v.map { String(format: "%.0f", $0) } ?? "—", o.isMet(by: v))
            },
            floors: (world.buildings[plan.building]?.builtLevels?.highest ?? 0) + 1,
            population: Progression.population(of: plan.building, in: world),
            units: world.tenants.values.filter { $0.buildingID == plan.building }.count,
            minCash: minCash, finalCash: world.ledger.cash, loans: world.ledger.loans,
            unitsBuilt: world.rooms.values.filter { $0.buildingID == plan.building && library.buildCatalog.spec($0.definitionID)?.rentPerModule != nil }.count,
            market: "prospects \(world.market.prospects), signed \(world.market.signed), moved out \(world.market.movedOut); declined: "
                + DeclineReason.allCases.map { "\($0.rawValue) \(world.market.declines($0))" }.joined(separator: ", "),
            log: log)
    }

    // MARK: Turns

    /// Day one: basement, ground floor with lobbies, the first storey, stairs and an elevator.
    mutating func setUp(_ plan: TowerPlan, world: inout GameWorld) {
        let staff = world.restrictions?.staffForbidden != true
        var c: [BuildCommand] = [-1, 0].map { .buildFloor(building: plan.building, level: $0, span: plan.span) }
        c += [place(plan, "stairs", plan.stairs, -1, 0), place(plan, "elevator-shaft", plan.elevatorA, -1, 0)]
        c += plan.basement(staff: staff)
        c += [plan.place("lobby", plan.left, 0), plan.place("lobby", plan.right, 0)]
        _ = run(c, world: &world, note: "set up")
        for _ in 0..<2 { guard addFloor(plan, world: &world) else { break } }
    }

    /// Each morning: grow while the cash allows, add elevators, hire staff, buy land.
    mutating func morning(_ plan: TowerPlan, def: ScenarioDefinition, world: inout GameWorld) {
        let day = SimClock.day(world.clock.tick) + 1
        var built = 0
        while built < floorsPerDay, addFloor(plan, world: &world) { built += 1 }
        let top = world.buildings[plan.building]?.builtLevels?.highest ?? 0
        if top >= 6, !hasRoom(plan.elevatorB, world) {
            _ = run([place(plan, "elevator-shaft", plan.elevatorB, -1, top)], world: &world, note: "D\(day) second elevator")
        }
        if (world.buildings[plan.building]?.standing.classLevel ?? 0) >= 1, !hasRoom(plan.service, world) {
            _ = run([place(plan, "service-elevator", plan.service, -1, top)], world: &world, note: "D\(day) service elevator")
        }
        if world.restrictions?.staffForbidden != true {
            let floors = top + 2
            for (role, per) in [(PersonRole.janitor, 8), (.technician, 12)] {
                let have = world.people.values.filter { $0.role == role && $0.buildingID == plan.building }.count
                if have < (floors + per - 1) / per {
                    FacilitiesManagement.hire(role, building: plan.building, world: &world, rules: engine.rules, catalog: library.buildCatalog)
                }
            }
        }
        if def.objectives.contains(where: { $0.metric == .properties }),
           let offer = Estate.offers(world: world, library: library).min(by: { $0.price < $1.price }),
           world.ledger.cash > offer.price + 2 * reserve,
           (try? Estate.buy(offer.plot.id, world: &world, library: library)) != nil {
            log.append("D\(day) bought \(offer.plot.name)")
        }
    }

    /// Builds the next storey with its rooms and raises the shafts, if affordable now.
    mutating func addFloor(_ plan: TowerPlan, world: inout GameWorld) -> Bool {
        guard let b = world.buildings[plan.building] else { return false }
        let level = (b.builtLevels?.highest ?? 0) + 1
        var c: [BuildCommand] = [.buildFloor(building: plan.building, level: level, span: plan.span)]
        for room in world.rooms(in: plan.building) where library.buildCatalog.spec(room.definitionID)?.kind == .shaft {
            c.append(.resizeRoom(room.id, floors: FloorSpan(lowest: room.floors.lowest, highest: level)))
        }
        if plan.isPlantFloor(level) {
            c += plan.plantFloor(level)
        } else {
            let kind = unitKind(level: level, world: world)
            c += plan.fill(plan.left, with: kind, level: level, catalog: library.buildCatalog)
            c += plan.fill(plan.right, with: kind, level: level, catalog: library.buildCatalog)
        }
        return run(c, world: &world, note: nil)
    }

    /// Offices on two floors of three, flats on the third — offices only when flats are forbidden.
    func unitKind(level: Int, world: GameWorld) -> String {
        if world.restrictions?.forbids("apartment-studio") == true { return "office-small" }
        return level % 3 == 0 ? "apartment-studio" : "office-small"
    }

    func hasRoom(_ columns: ColumnSpan, _ world: GameWorld) -> Bool {
        world.rooms.values.contains { $0.columns.overlaps(columns) && $0.floors.lowest < 0 }
    }

    func place(_ plan: TowerPlan, _ def: String, _ columns: ColumnSpan, _ lo: Int, _ hi: Int) -> BuildCommand {
        .placeRoom(building: plan.building, definition: def, columns: columns, floors: FloorSpan(lowest: lo, highest: hi))
    }

    /// Applies commands all or nothing: priced on a copy first, then only if the cash above
    /// the reserve pays for them. The first refusal is logged once.
    mutating func run(_ commands: [BuildCommand], world: inout GameWorld, note: String?) -> Bool {
        var trial = world
        var cost = 0
        for c in commands {
            do { cost += try construction.apply(c, to: &trial).plan.cost } catch {
                let line = "D\(SimClock.day(world.clock.tick) + 1) blocked: \(error)"
                if log.last != line { log.append(line) }
                return false
            }
        }
        guard world.ledger.cash - cost >= reserve else { return false }
        var copy = world
        do {
            for c in commands { try history.perform(c, engine: construction, world: &copy) }
        } catch { return false }
        world = copy
        PopulationSync.sync(&world, catalog: library.buildCatalog, rules: library.simulationRules)
        if let note { log.append(note) }
        return true
    }
}
