import Foundation

public enum BuildingTag {}
public typealias BuildingID = EntityID<BuildingTag>

/// Below-grade structure that a tower stands on.
public struct Foundation: Codable, Hashable, Sendable {
    /// Excavated basement levels (0 = slab on grade).
    public var basementFloors: Int
    /// Depth of pile tips below grade in meters.
    public var pileDepth: Double
    /// Horizontal pile spacing in modules.
    public var pileSpacing: Int

    public init(basementFloors: Int, pileDepth: Double, pileSpacing: Int) {
        self.basementFloors = basementFloors
        self.pileDepth = pileDepth
        self.pileSpacing = pileSpacing
    }

    /// Structural dimensions shared by model validation and art (meters).
    public static let retainingWallThickness = 0.6
    public static let raftThickness = 1.2
    public static let wallToeBelowRaft = 2.0
    public static let pileDiameter = 0.9

    /// Y of the underside of the raft slab.
    public func raftBottomY(grid: GridSpec) -> Double {
        grid.y(ofFloor: -basementFloors) - (basementFloors > 0 ? Foundation.raftThickness : grid.slabThickness)
    }
}

/// A building on a property. Phase 1: footprint + foundation only; floors and rooms
/// arrive with construction (Phase 2).
public struct Building: Codable, Hashable, Sendable, Identifiable {
    public let id: BuildingID
    public var propertyID: PropertyID
    public var name: String
    /// Columns occupied at grade.
    public var footprint: ColumnSpan
    public var foundation: Foundation

    public init(id: BuildingID, propertyID: PropertyID, name: String, footprint: ColumnSpan, foundation: Foundation) {
        self.id = id
        self.propertyID = propertyID
        self.name = name
        self.footprint = footprint
        self.foundation = foundation
    }
}
