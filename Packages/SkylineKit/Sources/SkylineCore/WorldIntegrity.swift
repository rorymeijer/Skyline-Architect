import Foundation

/// Structural consistency checks for a world, used after loading saves so an invalid
/// world is rejected instead of silently producing a broken game.
public enum WorldIntegrityError: Error, Equatable, CustomStringConvertible {
    case danglingReference(String)
    case idAllocatorBehind(UInt32)
    case plateOrder(BuildingID)
    case roomWithoutFloor(RoomID)
    case overlappingRooms(RoomID, RoomID)

    public var description: String {
        switch self {
        case .danglingReference(let what): "Dangling reference: \(what)"
        case .idAllocatorBehind(let raw): "ID allocator is behind existing id \(raw)"
        case .plateOrder(let b): "Floor plates of building \(b) are unsorted or duplicated"
        case .roomWithoutFloor(let r): "Room \(r) is not on built floors"
        case .overlappingRooms(let a, let b): "Rooms \(a) and \(b) overlap"
        }
    }
}

extension GameWorld {
    public func validateIntegrity() throws {
        var maxID: UInt32 = 0
        for c in cities { maxID = max(maxID, c.id.raw) }
        for p in properties {
            maxID = max(maxID, p.id.raw)
            guard cities.contains(p.cityID) else { throw WorldIntegrityError.danglingReference("property \(p.id) → city \(p.cityID)") }
        }
        for b in buildings {
            maxID = max(maxID, b.id.raw)
            guard properties.contains(b.propertyID) else { throw WorldIntegrityError.danglingReference("building \(b.id) → property \(b.propertyID)") }
            for (a, c) in zip(b.floors, b.floors.dropFirst()) where a.level >= c.level {
                throw WorldIntegrityError.plateOrder(b.id)
            }
        }
        var roomsByBuilding: [BuildingID: [Room]] = [:]
        for r in rooms {
            maxID = max(maxID, r.id.raw)
            guard let b = buildings[r.buildingID] else { throw WorldIntegrityError.danglingReference("room \(r.id) → building \(r.buildingID)") }
            for level in r.floors.lowest...r.floors.highest {
                guard let plate = b.plate(at: level), plate.span.contains(r.columns) else { throw WorldIntegrityError.roomWithoutFloor(r.id) }
            }
            if let clash = roomsByBuilding[r.buildingID]?.first(where: { $0.overlaps(columns: r.columns, floors: r.floors) }) {
                throw WorldIntegrityError.overlappingRooms(clash.id, r.id)
            }
            roomsByBuilding[r.buildingID, default: []].append(r)
        }
        guard ids.next > maxID else { throw WorldIntegrityError.idAllocatorBehind(maxID) }
    }
}
