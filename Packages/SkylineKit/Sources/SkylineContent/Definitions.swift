import Foundation
import SkylineCore
import SkylineSimulation

/// Content definitions are plain, declarative data decoded from JSON packs.
/// They describe *kinds* of things; the model stores *instances*.

public struct CityDefinition: Codable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var description: String
    /// Seed for procedural content tied to this city (backdrop skyline, …).
    public var seed: UInt64
    /// Ground profile top-down; the last stratum is treated as unbounded bedrock.
    public var geology: [SoilStratum]
}

public struct PlotDefinition: Codable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var cityID: String
    public var frontageModules: Int
    public var maxBasementFloors: Int
    public var siteMarginModules: Int
}

public struct StartDefinition: Codable, Hashable, Sendable {
    /// Sandbox: everything unlocked. Standard: rooms and height unlock with the building
    /// class (Phase 11).
    public enum Mode: String, Codable, Sendable { case sandbox, standard }

    public struct StartingFoundation: Codable, Hashable, Sendable {
        public var buildingName: String
        public var footprintOffsetModules: Int
        public var footprintModules: Int
        public var basementFloors: Int
        public var pileDepthMeters: Double
        public var pileSpacingModules: Int
    }

    public var id: String
    public var name: String
    public var mode: Mode
    public var cityID: String
    public var plotID: String
    public var propertyName: String
    public var startingFoundation: StartingFoundation?
    /// Cash at the start (Phase 9; nil = 0).
    public var startingCash: Int?
}

/// `progression.json` (Phase 11): reputation rules and the ordered building classes.
public struct ProgressionDefinition: Codable, Hashable, Sendable {
    public var reputation: ReputationRules
    public var classes: [BuildingClass]

    func problems(rooms: Set<String>) -> [String] {
        var p = reputation.problems
        if classes.isEmpty { p.append("progression: no building classes") }
        var ids = Set<String>()
        for (i, c) in classes.enumerated() {
            if !ids.insert(c.id).inserted { p.append("class '\(c.id)' defined twice") }
            if c.population < 0 || !(0...100).contains(c.reputation) { p.append("class '\(c.id)': population ≥ 0, reputation 0…100") }
            for r in c.requiredRooms where !rooms.contains(r) { p.append("class '\(c.id)': unknown room '\(r)'") }
            if i > 0, let prev = classes[i - 1].maxFloor, let max = c.maxFloor, max < prev { p.append("class '\(c.id)': maxFloor below the previous class") }
            if i > 0, classes[i - 1].maxFloor == nil, c.maxFloor != nil { p.append("class '\(c.id)': maxFloor after an unlimited class") }
        }
        if let first = classes.first, first.population != 0 || first.reputation != 0 || !first.requiredRooms.isEmpty {
            p.append("class '\(first.id)': the first class is where buildings start and cannot have requirements")
        }
        return p
    }
}
