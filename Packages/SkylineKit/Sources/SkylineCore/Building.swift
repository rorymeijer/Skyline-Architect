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

/// One storey's slab: a single contiguous run of columns at a floor level.
/// Setbacks are expressed by upper plates spanning fewer columns.
public struct FloorPlate: Codable, Hashable, Sendable {
    public var level: Int
    public var span: ColumnSpan

    public init(level: Int, span: ColumnSpan) {
        self.level = level
        self.span = span
    }
}

/// A building on a property: footprint, foundation and its floor plates. Rooms live in
/// `GameWorld.rooms` and reference the building (DECISIONS D-005).
public struct Building: Codable, Hashable, Sendable, Identifiable {
    public let id: BuildingID
    public var propertyID: PropertyID
    public var name: String
    /// Columns occupied at grade.
    public var footprint: ColumnSpan
    public var foundation: Foundation
    /// Floor plates sorted by level, at most one per level.
    public internal(set) var floors: [FloorPlate]
    /// Player rent setting (Phase 9): asking rents are multiplied by this (0.6…1.6).
    public var rentLevel: Double = 1
    /// Reputation and class (Phase 11).
    public var standing = Standing()
    /// Lighting energy used since the last daily closing, kWh (Phase 12; simulation-owned).
    public var lightingKWh = 0.0

    public init(id: BuildingID, propertyID: PropertyID, name: String, footprint: ColumnSpan,
                foundation: Foundation, floors: [FloorPlate] = []) {
        self.id = id
        self.propertyID = propertyID
        self.name = name
        self.footprint = footprint
        self.foundation = foundation
        self.floors = floors.sorted { $0.level < $1.level }
    }

    /// Footprint and foundation together: what `extendFoundation` changes (0.21).
    public struct Groundwork: Hashable, Sendable {
        public var footprint: ColumnSpan
        public var foundation: Foundation
    }

    public var groundwork: Groundwork { Groundwork(footprint: footprint, foundation: foundation) }

    public func plate(at level: Int) -> FloorPlate? {
        // Plates are kept in level order and are normally contiguous: index directly (Phase 19).
        if let first = floors.first, let last = floors.last, last.level - first.level + 1 == floors.count {
            let i = level - first.level
            return floors.indices.contains(i) ? floors[i] : nil
        }
        return floors.first { $0.level == level }
    }

    /// Lowest and highest built levels, or nil if no floors exist.
    public var builtLevels: FloorSpan? {
        guard let lo = floors.first?.level, let hi = floors.last?.level else { return nil }
        return FloorSpan(lowest: lo, highest: hi)
    }

    /// Inserts, replaces (non-nil) or removes (nil) the plate at `level`, keeping order.
    mutating func setPlate(_ plate: FloorPlate?, at level: Int) {
        floors.removeAll { $0.level == level }
        if let plate {
            precondition(plate.level == level)
            let i = floors.firstIndex { $0.level > level } ?? floors.count
            floors.insert(plate, at: i)
        }
    }
}
