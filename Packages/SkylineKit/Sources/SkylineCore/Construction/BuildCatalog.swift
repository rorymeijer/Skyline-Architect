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

    public init(id: String, name: String, category: String, kind: RoomKind, appearance: String,
                minWidth: Int, maxWidth: Int, minFloors: Int, maxFloors: Int,
                lowestLevel: Int? = nil, highestLevel: Int? = nil, costPerModule: Int) {
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
    }
}

/// Global construction rules (`build-rules.json`).
public struct BuildRules: Codable, Hashable, Sendable {
    public var slabCostPerModule: Int
    public var basementSlabCostPerModule: Int
    /// How many modules an upper plate may overhang the plate below on each side.
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
    private let index: [String: Int]

    public init(rules: BuildRules, specs: [RoomSpec]) {
        self.rules = rules
        self.specs = specs
        var index: [String: Int] = [:]
        for (i, s) in specs.enumerated() where index[s.id] == nil { index[s.id] = i }
        self.index = index
    }

    public func spec(_ id: String) -> RoomSpec? { index[id].map { specs[$0] } }
}
