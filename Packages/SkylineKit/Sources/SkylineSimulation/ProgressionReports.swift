import Foundation
import SkylineCore

/// A building's class, reputation and the way to the next class, for the UI (Phase 11).
public struct ProgressionSummary: Equatable, Sendable {
    /// Standard game (unlocks by class) rather than a sandbox.
    public var byClass = false
    public var classLevel = 0
    public var className = "—"
    public var reputation = 0.0
    /// Today's view of the building (what reputation is moving toward).
    public var assessment: ReputationAssessment?
    public var nextClassName: String?
    public var requirements: [ClassRequirement] = []
    /// What the next class unlocks (room types, tenant types, height), in content order.
    public var nextUnlocks: [String] = []
    /// Highest floor that may be built now (standard game; nil = no limit).
    public var maxFloor: Int?
    /// Room types still locked, with the class that unlocks them (standard game).
    public var lockedRooms: [String: String] = [:]
    public var promotions: [Tick] = []

    public init() {}

    public static func make(world: GameWorld, engine: SimulationEngine, building: BuildingID?) -> ProgressionSummary {
        var s = ProgressionSummary()
        let classes = engine.catalog.classes
        guard let building, let b = world.buildings[building], !classes.isEmpty else { return s }
        let level = min(b.standing.classLevel, classes.count - 1)
        s.byClass = world.unlocks == .byClass
        s.classLevel = level
        s.className = classes[level].name
        s.reputation = b.standing.reputation
        s.promotions = b.standing.promotions
        s.assessment = Progression.assess(building, world: world, engine: engine)
        if s.byClass {
            s.maxFloor = classes[level].maxFloor
            for spec in engine.catalog.specs {
                if let c = spec.unlockClass, c > level, classes.indices.contains(c) { s.lockedRooms[spec.id] = classes[c].name }
            }
        }
        let next = level + 1
        guard classes.indices.contains(next) else { return s }
        s.nextClassName = classes[next].name
        s.requirements = Progression.requirements(for: next, building: building, world: world, catalog: engine.catalog)
        s.nextUnlocks = engine.catalog.specs.filter { $0.unlockClass == next }.map(\.name)
            + engine.rules.tenantTypes.filter { $0.minClass == next }.map { "\($0.name) tenants" }
        if classes[next].maxFloor != classes[level].maxFloor {
            s.nextUnlocks.append(classes[next].maxFloor.map { "Floors up to \(FloorLabel.label(for: $0))" } ?? "No height limit")
        }
        return s
    }
}
