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

    public init(id: RoomID, buildingID: BuildingID, definitionID: String, columns: ColumnSpan, floors: FloorSpan) {
        self.id = id
        self.buildingID = buildingID
        self.definitionID = definitionID
        self.columns = columns
        self.floors = floors
    }

    public func occupies(column: Int, floor: Int) -> Bool {
        columns.contains(column) && floors.contains(floor)
    }

    public func overlaps(columns other: ColumnSpan, floors otherFloors: FloorSpan) -> Bool {
        columns.overlaps(other) && floors.lowest <= otherFloors.highest && otherFloors.lowest <= floors.highest
    }
}
