import Foundation

public enum RoomTag {}
public typealias RoomID = EntityID<RoomTag>

/// Any placed space occupying grid cells of a building: rooms (offices, apartments,
/// lobbies, corridors) and vertical shafts (stairs, elevator shafts). What it *is* comes
/// from its content definition (`RoomSpec`); the model only stores where it is.
public struct Room: Codable, Hashable, Sendable, Identifiable {
    public let id: RoomID
    public var buildingID: BuildingID
    /// Content definition id (e.g. `"office-small"`).
    public var definitionID: String
    public var columns: ColumnSpan
    public var floors: FloorSpan
    /// Rented or sold (save format 15; nil = rented, the default of every unit).
    public var tenure: Tenure?
    /// Player rent setting of this unit on top of the building's rent level (0.6…1.6,
    /// save format 17; nil = 1). For new leases and appraisal; signed rents stay.
    public var rentFactor: Double?

    public init(id: RoomID, buildingID: BuildingID, definitionID: String, columns: ColumnSpan, floors: FloorSpan, tenure: Tenure? = nil) {
        self.id = id
        self.buildingID = buildingID
        self.definitionID = definitionID
        self.columns = columns
        self.floors = floors
        self.tenure = tenure
    }

    /// Sold to a private owner: no longer the player's to change or demolish.
    public var isPrivatelyOwned: Bool { tenure == .owned }

    public func occupies(column: Int, floor: Int) -> Bool {
        columns.contains(column) && floors.contains(floor)
    }

    public func overlaps(columns other: ColumnSpan, floors otherFloors: FloorSpan) -> Bool {
        columns.overlaps(other) && floors.lowest <= otherFloors.highest && otherFloors.lowest <= floors.highest
    }
}

/// How a unit is let (0.20.3): rented out, offered for sale, or sold. A sold flat stays
/// privately owned: when its owner moves out it is resold between private parties.
public enum Tenure: String, Codable, Hashable, Sendable {
    case rent, forSale, owned
}
