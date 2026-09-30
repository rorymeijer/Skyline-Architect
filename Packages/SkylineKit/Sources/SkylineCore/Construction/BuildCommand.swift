import Foundation

/// A player construction intent. Commands are the only way construction changes the
/// world, which makes validation, cost preview, undo and (later) replays uniform.
public enum BuildCommand: Codable, Hashable, Sendable {
    /// Builds a new plate or extends an existing one at `level` (spans must touch/overlap).
    case buildFloor(building: BuildingID, level: Int, span: ColumnSpan)
    /// Removes the whole plate at `level` (must be empty and carry nothing).
    case demolishFloor(building: BuildingID, level: Int)
    /// Places a room or shaft. A shaft may stand in front of rooms, which stay whole behind
    /// it (0.30); a room never overlaps a room, nor a shaft a shaft.
    case placeRoom(building: BuildingID, definition: String, columns: ColumnSpan, floors: FloorSpan)
    case demolishRoom(RoomID)
    /// Moves a shaft's top and/or bottom to `floors` (same columns), in front of any rooms
    /// there; the elevator car and its statistics stay.
    case resizeRoom(RoomID, floors: FloorSpan)
    /// Several commands as one step, applied in order (inverses of steps that changed
    /// more than one room).
    case batch([BuildCommand])
    /// Grows a building's foundation (Phase A, 0.21): a wider footprint within the plot,
    /// more basement levels and/or longer piles. Never shrinks it.
    case extendFoundation(building: BuildingID, footprint: ColumnSpan, foundation: Foundation)
    /// Restores a footprint and foundation exactly (the inverse of `extendFoundation`).
    case restoreFoundation(building: BuildingID, footprint: ColumnSpan, foundation: Foundation)
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
        case .resizeRoom: "Resize Shaft"
        case .batch: "Construction"
        case .extendFoundation: "Extend Foundation"
        case .restoreFoundation: "Foundation Change"
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
    /// Wider than the floor below allows (`BuildRules.maxCantileverModules` per side).
    case overhang(max: Int)
    case notContiguous
    case nothingToBuild
    case noFloor(level: Int)
    case floorNotEmpty
    case carriesFloorAbove
    case widthOutOfRange(min: Int, max: Int)
    case heightOutOfRange(min: Int, max: Int)
    case levelNotAllowed
    case overlaps(RoomID)
    /// A room in the way would be left narrower than its minimum width.
    /// Only shafts can be made taller or shorter.
    case notResizable
    /// The unit was sold: it belongs to its owner (0.20.3).
    case privatelyOwned
    /// Foundations only grow: a narrower footprint, fewer basements or shorter piles.
    case foundationCanOnlyGrow
    /// More basement levels than the plot allows.
    case basementTooDeep(allowed: Int)
    /// Piles too short: for the raft (at `needed` m) or for the height (`needed` m to carry it).
    case pilesTooShort(needed: Double)
    /// The widened footprint would run into another building.
    case footprintOverlapsBuilding
    /// The widened footprint would leave the plot's frontage.
    case outsidePlot
    /// Standard game: the room type or height needs a higher building class (Phase 11).
    case locked(className: String)
    /// The scenario forbids this room type, or building this high (Phase C).
    case forbiddenInScenario
    case aboveScenarioHeight(max: Int)

    public var description: String {
        switch self {
        case .forbiddenInScenario: "Not allowed in this scenario"
        case let .aboveScenarioHeight(max): "This scenario allows floors up to \(FloorLabel.label(for: max))"
        case .unknownBuilding: "No building here"
        case .unknownRoom: "Nothing to demolish"
        case .unknownDefinition(let id): "Unknown room type \(id)"
        case .emptySpan: "Nothing selected"
        case .outsideFootprint: "Outside the foundation footprint"
        case .noExcavation(let l): "No excavation for \(FloorLabel.label(for: l))"
        case .unsupported: "Needs a floor below to rest on"
        case .overhang(let m): m == 0 ? "Cannot be wider than the floor below" : "Can stick out at most \(m) m past the floor below"
        case .notContiguous: "Must connect to the existing floor"
        case .nothingToBuild: "Already built"
        case .noFloor(let l): "No floor at \(FloorLabel.label(for: l))"
        case .floorNotEmpty: "Floor still has rooms"
        case .carriesFloorAbove: "Floor supports other floors"
        case .widthOutOfRange(let a, let b): a == b ? "Must be \(a) m wide" : "Must be \(a)–\(b) m wide"
        case .heightOutOfRange(let a, let b): a == b ? "Must span \(a) floor(s)" : "Must span \(a)–\(b) floors"
        case .levelNotAllowed: "Not allowed on this floor"
        case .overlaps: "Overlaps an existing room"
        case .notResizable: "Only shafts can be made taller or shorter"
        case .privatelyOwned: "Sold to a private owner"
        case .foundationCanOnlyGrow: "A foundation can only be made larger"
        case .basementTooDeep(let n): "The plot allows \(n) basement level\(n == 1 ? "" : "s")"
        case .pilesTooShort(let m): "Needs piles of at least \(Int(m.rounded(.up))) m"
        case .footprintOverlapsBuilding: "Runs into another building"
        case .outsidePlot: "Outside the plot"
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
