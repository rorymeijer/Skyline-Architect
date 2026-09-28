import Foundation
import SkylineCore

/// How reputation is assessed and what it does (`progression.json` → `reputation`, Phase 11).
public struct ReputationRules: Codable, Hashable, Sendable {
    /// Relative weight of each component of the daily assessment (normalized).
    public struct Weights: Codable, Hashable, Sendable {
        public var satisfaction: Double
        public var services: Double
        public var waits: Double
        public var occupancy: Double

        public init(satisfaction: Double, services: Double, waits: Double, occupancy: Double) {
            self.satisfaction = satisfaction
            self.services = services
            self.waits = waits
            self.occupancy = occupancy
        }
    }

    /// Fraction of the gap to the day's assessment closed each morning (0…1).
    public var dailyAdjustment: Double
    public var weights: Weights
    /// Average elevator waits up to this score 1, from `badWaitSeconds` on 0 (linear between).
    public var goodWaitSeconds: Double
    public var badWaitSeconds: Double
    /// Reputation points lost per tenant that moved out that day.
    public var moveOutPenalty: Double
    /// Prospective tenants per day are multiplied by this at reputation 0 and 100 (linear).
    public var demandAtZero: Double
    public var demandAtHundred: Double

    public init(dailyAdjustment: Double, weights: Weights, goodWaitSeconds: Double, badWaitSeconds: Double,
                moveOutPenalty: Double, demandAtZero: Double, demandAtHundred: Double) {
        self.dailyAdjustment = dailyAdjustment
        self.weights = weights
        self.goodWaitSeconds = goodWaitSeconds
        self.badWaitSeconds = badWaitSeconds
        self.moveOutPenalty = moveOutPenalty
        self.demandAtZero = demandAtZero
        self.demandAtHundred = demandAtHundred
    }

    public var problems: [String] {
        var p: [String] = []
        let w = weights
        if [w.satisfaction, w.services, w.waits, w.occupancy].contains(where: { $0 < 0 }) || w.satisfaction + w.services + w.waits + w.occupancy <= 0 {
            p.append("reputation: weights must be non-negative and not all zero")
        }
        if !(0...1).contains(dailyAdjustment) { p.append("reputation: dailyAdjustment must be 0…1") }
        if goodWaitSeconds < 0 || badWaitSeconds <= goodWaitSeconds { p.append("reputation: need 0 ≤ goodWaitSeconds < badWaitSeconds") }
        if moveOutPenalty < 0 { p.append("reputation: moveOutPenalty must be ≥ 0") }
        if demandAtZero < 0 || demandAtHundred < 0 { p.append("reputation: demand multipliers must be ≥ 0") }
        return p
    }
}

/// One day's view of a building (each component 0…1) and the reputation it points to.
public struct ReputationAssessment: Equatable, Sendable {
    /// Average tenant satisfaction (0.5 without tenants).
    public var satisfaction: Double
    /// Average services level (utilities, cleanliness, condition) of the rentable units.
    public var services: Double
    /// Measured elevator waits (1 without elevators or data).
    public var waits: Double
    /// Leased share of the rentable units.
    public var occupancy: Double
    public var moveOuts: Int
    /// 0…100.
    public var target: Double
    public var population: Int
    /// Average elevator wait in seconds (nil without enough data).
    public var averageWait: Double?
}

/// A requirement for the next building class, with where the building stands.
public struct ClassRequirement: Equatable, Sendable {
    public var label: String
    public var current: Double
    public var needed: Double
    public var met: Bool
}

/// Reputation, building classes and promotion (Phase 11). See PROGRESSION.md.
public enum Progression {
    /// Tenant members of a building (staff excluded).
    public static func population(of building: BuildingID, in world: GameWorld) -> Int {
        world.people.values.reduce(0) { $0 + ($1.buildingID == building && $1.tenantID != nil ? 1 : 0) }
    }

    public static func assess(_ building: BuildingID, world: GameWorld, engine: SimulationEngine, moveOuts: Int = 0) -> ReputationAssessment? {
        guard let rules = engine.rules.progression else { return nil }
        let tenants = world.tenants.values.filter { $0.buildingID == building }
        let satisfaction = tenants.isEmpty ? 0.5 : tenants.reduce(0) { $0 + $1.satisfaction } / Double(tenants.count)
        let units = world.rooms(in: building).filter { engine.catalog.spec($0.definitionID)?.rentPerModule != nil }
        let service = engine.rules.facilities == nil ? nil
            : Utilities.allocate(building: building, world: world, catalog: engine.catalog, rules: engine.rules)
        let services = units.isEmpty ? 1
            : units.reduce(0) { $0 + Leasing.servicesLevel(of: $1, world: world, service: service) } / Double(units.count)
        let occupancy = units.isEmpty ? 0 : Double(Set(tenants.map(\.room)).count) / Double(units.count)
        var boardings = 0, waited = 0.0
        for bank in ElevatorBanks.banks(in: world, rules: engine.rules, building: building) {
            let s = ElevatorBanks.stats(of: bank, in: world)
            guard s.boardings >= 10 else { continue }
            boardings += s.boardings
            waited += s.averageWait * Double(s.boardings)
        }
        let averageWait = boardings > 0 ? waited / Double(boardings) : nil
        let waits = averageWait.map { Leasing.clamp(1 - ($0 - rules.goodWaitSeconds) / (rules.badWaitSeconds - rules.goodWaitSeconds)) } ?? 1
        let w = rules.weights
        let sum = w.satisfaction + w.services + w.waits + w.occupancy
        let score = (w.satisfaction * satisfaction + w.services * services + w.waits * waits + w.occupancy * occupancy) / sum
        let target = min(max(100 * score - rules.moveOutPenalty * Double(moveOuts), 0), 100)
        return ReputationAssessment(satisfaction: satisfaction, services: services, waits: waits, occupancy: occupancy, moveOuts: moveOuts,
                                    target: target, population: population(of: building, in: world), averageWait: averageWait)
    }

    /// What class `index` asks for, and whether the building has it.
    public static func requirements(for index: Int, building: BuildingID, world: GameWorld, catalog: BuildCatalog) -> [ClassRequirement] {
        guard catalog.classes.indices.contains(index), let b = world.buildings[building] else { return [] }
        let c = catalog.classes[index]
        let population = Double(population(of: building, in: world))
        var result = [ClassRequirement(label: "Population", current: population, needed: Double(c.population), met: population >= Double(c.population)),
                      ClassRequirement(label: "Reputation", current: b.standing.reputation.rounded(), needed: c.reputation,
                                       met: b.standing.reputation >= c.reputation)]
        let rooms = world.rooms(in: building)
        for id in c.requiredRooms {
            let has = rooms.contains { $0.definitionID == id }
            result.append(ClassRequirement(label: catalog.spec(id)?.name ?? id, current: has ? 1 : 0, needed: 1, met: has))
        }
        return result
    }

    /// Multiplier on every tenant type's prospects: follows the average reputation of the
    /// buildings that have rentable units (1 without reputation rules or such buildings).
    /// `buildings` limits it to one city's buildings (Phase 15; nil = all).
    public static func demandMultiplier(world: GameWorld, engine: SimulationEngine, buildings only: Set<BuildingID>? = nil) -> Double {
        guard let rules = engine.rules.progression else { return 1 }
        let rentable = Set(world.rooms.values.filter { engine.catalog.spec($0.definitionID)?.rentPerModule != nil }.map(\.buildingID))
        let buildings = world.buildings.values.filter { rentable.contains($0.id) && (only?.contains($0.id) ?? true) }
        guard !buildings.isEmpty else { return 1 }
        let reputation = buildings.reduce(0) { $0 + $1.standing.reputation } / Double(buildings.count)
        return rules.demandAtZero + (rules.demandAtHundred - rules.demandAtZero) * reputation / 100
    }
}

extension SimulationEngine {
    /// Morning step (after the tenant reviews): reputation moves toward the day's
    /// assessment; a building meeting every requirement of the next class is promoted
    /// (at most one class per day, never demoted).
    func standingDaily(at now: Tick, moveOuts: [BuildingID: Int], world: inout GameWorld) {
        guard let rules = rules.progression else { return }
        for building in world.buildings.values {
            guard let a = Progression.assess(building.id, world: world, engine: self, moveOuts: moveOuts[building.id] ?? 0) else { continue }
            var standing = building.standing
            standing.reputation += (a.target - standing.reputation) * rules.dailyAdjustment
            world.setStanding(standing, building: building.id)
            let next = standing.classLevel + 1
            let requirements = Progression.requirements(for: next, building: building.id, world: world, catalog: catalog)
            if !requirements.isEmpty, requirements.allSatisfy(\.met) {
                standing.classLevel = next
                standing.promotions.append(now)
                world.setStanding(standing, building: building.id)
            }
        }
    }
}
