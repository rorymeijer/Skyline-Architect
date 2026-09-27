import Foundation

/// A player construction intent. Commands are the only way construction changes the
/// world, which makes validation, cost preview, undo and (later) replays uniform.
public enum BuildCommand: Codable, Hashable, Sendable {
    /// Builds a new plate or extends an existing one at `level` (spans must touch/overlap).
    case buildFloor(building: BuildingID, level: Int, span: ColumnSpan)
    /// Removes the whole plate at `level` (must be empty and carry nothing).
    case demolishFloor(building: BuildingID, level: Int)
    case placeRoom(building: BuildingID, definition: String, columns: ColumnSpan, floors: FloorSpan)
    case demolishRoom(RoomID)
    /// Restores exact prior state; produced only as inverses for undo/redo.
    case restorePlate(building: BuildingID, level: Int, plate: FloorPlate?)
    case restoreRoom(Room)

    /// Short human-readable name (menus: "Undo Build Floor").
    public var actionName: String {
        switch self {
        case .buildFloor: "Build Floor"
        case .demolishFloor: "Demolish Floor"
        case .placeRoom: "Place Room"
        case .demolishRoom: "Demolish Room"
        case .restorePlate: "Floor Change"
        case .restoreRoom: "Room Change"
        }
    }
}

public enum ConstructionError: Error, Equatable, Sendable, CustomStringConvertible {
    case unknownBuilding
    case unknownRoom
    case unknownDefinition(String)
    case emptySpan
    case outsideFootprint
    case noExcavation(level: Int)
    case unsupported
    case notContiguous
    case nothingToBuild
    case noFloor(level: Int)
    case floorNotEmpty
    case carriesFloorAbove
    case widthOutOfRange(min: Int, max: Int)
    case heightOutOfRange(min: Int, max: Int)
    case levelNotAllowed
    case overlaps(RoomID)
    /// Standard game: the room type or height needs a higher building class (Phase 11).
    case locked(className: String)

    public var description: String {
        switch self {
        case .unknownBuilding: "No building here"
        case .unknownRoom: "Nothing to demolish"
        case .unknownDefinition(let id): "Unknown room type \(id)"
        case .emptySpan: "Nothing selected"
        case .outsideFootprint: "Outside the foundation footprint"
        case .noExcavation(let l): "No excavation for \(FloorLabel.label(for: l))"
        case .unsupported: "Needs a floor below to rest on"
        case .notContiguous: "Must connect to the existing floor"
        case .nothingToBuild: "Already built"
        case .noFloor(let l): "No floor at \(FloorLabel.label(for: l))"
        case .floorNotEmpty: "Floor still has rooms"
        case .carriesFloorAbove: "Floor supports other floors"
        case .widthOutOfRange(let a, let b): a == b ? "Must be \(a) m wide" : "Must be \(a)–\(b) m wide"
        case .heightOutOfRange(let a, let b): a == b ? "Must span \(a) floor(s)" : "Must span \(a)–\(b) floors"
        case .levelNotAllowed: "Not allowed on this floor"
        case .overlaps: "Overlaps an existing room"
        case .locked(let name): "Unlocks at \(name)"
        }
    }
}

/// Result of validating a command: its cost (negative = refund) and the grid region whose
/// appearance changes (for cost display and renderer invalidation).
public struct ConstructionPlan: Equatable, Sendable {
    public var cost: Int
    public var buildingID: BuildingID
    public var columns: ColumnSpan
    public var floors: FloorSpan

    public init(cost: Int, buildingID: BuildingID, columns: ColumnSpan, floors: FloorSpan) {
        self.cost = cost
        self.buildingID = buildingID
        self.columns = columns
        self.floors = floors
    }
}

/// A command that was applied: what it cost and how to undo it.
public struct AppliedConstruction: Equatable, Sendable {
    public var plan: ConstructionPlan
    public var inverse: BuildCommand
    /// The room created by `placeRoom`, if any.
    public var createdRoom: RoomID?
}
