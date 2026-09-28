import Foundation

/// Whether a placeable occupies a fixed-height block (room) or spans a variable range of
/// floors (vertical shaft such as stairs or an elevator hoistway).
public enum RoomKind: String, Codable, Hashable, Sendable {
    case room, shaft
}

/// Construction-relevant description of a placeable space, decoded directly from content
/// (`rooms.json`). Only data: the engine never switches on ids.
public struct RoomSpec: Codable, Hashable, Sendable {
    public var id: String
    public var name: String
    /// Grouping for UI and later simulation (e.g. "office", "residential", "circulation").
    public var category: String
    public var kind: RoomKind
    /// Visual style key interpreted by the presentation layer.
    public var appearance: String
    public var minWidth: Int
    public var maxWidth: Int
    /// Rooms: exact height in floors when `minFloors == maxFloors`. Shafts: allowed range.
    public var minFloors: Int
    public var maxFloors: Int
    /// Lowest / highest floor level this space may occupy (nil = unrestricted).
    public var lowestLevel: Int?
    public var highestLevel: Int?
    /// Construction cost per module per floor.
    public var costPerModule: Int
    /// Asking rent per module per month for leasable units (nil = not leasable). Who may
    /// rent it is defined by tenant types (`tenants.json`, Phase 8).
    public var rentPerModule: Int?
    /// Noise this space makes for its neighbours (0…1; nil = silent).
    public var noise: Double?
    /// Upkeep per module (per floor for shafts) per game day (Phase 9; nil = none).
    public var maintenancePerModulePerDay: Int?
    /// Utility use per module per floor, by utility id (Phase 10; e.g. "electricity").
    public var utilityDemand: [String: Double]?
    /// Utility capacity per module of width, by utility id (equipment rooms, Phase 10).
    public var utilitySupply: [String: Double]?
    /// Floors above and below an equipment room that it can serve.
    public var utilityRange: Int?
    /// Condition lost per game day (0…1 scale; nil = no wear).
    public var wearPerDay: Double?
    /// Vertical transport provided by a shaft (`"stairs"`; `"elevator"` from Phase 6).
    public var transport: String?
    /// Building class index needed to place it in a standard game (Phase 11; nil = 0).
    public var unlockClass: Int?
    /// How the room is lit (Phase 12; nil = no lights, e.g. shafts).
    public var lighting: LightingSpec?
    /// Sprinkler coverage of a fire control room: floors above and below (Phase 14).
    public var fireProtection: Int?

    public init(id: String, name: String, category: String, kind: RoomKind, appearance: String,
                minWidth: Int, maxWidth: Int, minFloors: Int, maxFloors: Int,
                lowestLevel: Int? = nil, highestLevel: Int? = nil, costPerModule: Int,
                rentPerModule: Int? = nil, noise: Double? = nil, maintenancePerModulePerDay: Int? = nil, transport: String? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.kind = kind
        self.appearance = appearance
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.minFloors = minFloors
        self.maxFloors = maxFloors
        self.lowestLevel = lowestLevel
        self.highestLevel = highestLevel
        self.costPerModule = costPerModule
        self.rentPerModule = rentPerModule
        self.noise = noise
        self.maintenancePerModulePerDay = maintenancePerModulePerDay
        self.transport = transport
    }
}

/// Global construction rules (`build-rules.json`).
public struct BuildRules: Codable, Hashable, Sendable {
    public var slabCostPerModule: Int
    public var basementSlabCostPerModule: Int
    /// How many modules an upper plate may overhang the plate below on each side (the base
    /// game allows none: a floor never sticks out past the floor below).
    public var maxCantileverModules: Int
    /// Fraction of construction cost returned on demolition (0…1).
    public var demolitionRefund: Double

    public init(slabCostPerModule: Int, basementSlabCostPerModule: Int, maxCantileverModules: Int, demolitionRefund: Double) {
        self.slabCostPerModule = slabCostPerModule
        self.basementSlabCostPerModule = basementSlabCostPerModule
        self.maxCantileverModules = maxCantileverModules
        self.demolitionRefund = demolitionRefund
    }
}

/// Everything the construction engine needs to know about content.
public struct BuildCatalog: Sendable {
    public let rules: BuildRules
    public let specs: [RoomSpec]
    /// Building classes in order (Phase 11; empty = no classes, nothing gated).
    public let classes: [BuildingClass]
    private let index: [String: Int]

    public init(rules: BuildRules, specs: [RoomSpec], classes: [BuildingClass] = []) {
        self.rules = rules
        self.specs = specs
        self.classes = classes
        var index: [String: Int] = [:]
        for (i, s) in specs.enumerated() where index[s.id] == nil { index[s.id] = i }
        self.index = index
    }

    public func spec(_ id: String) -> RoomSpec? { index[id].map { specs[$0] } }
}
