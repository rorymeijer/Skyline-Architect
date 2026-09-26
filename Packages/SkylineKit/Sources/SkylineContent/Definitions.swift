import Foundation
import SkylineCore

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
    public enum Mode: String, Codable, Sendable { case sandbox }

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
}
