import Foundation

/// Structural consistency checks for a world, used after loading saves so an invalid
/// world is rejected instead of silently producing a broken game.
public enum WorldIntegrityError: Error, Equatable, CustomStringConvertible {
    case danglingReference(String)
    case idAllocatorBehind(UInt32)
    case plateOrder(BuildingID)
    case roomWithoutFloor(RoomID)
    case overlappingRooms(RoomID, RoomID)
    case invalidStanding(BuildingID)

    public var description: String {
        switch self {
        case .danglingReference(let what): "Dangling reference: \(what)"
        case .idAllocatorBehind(let raw): "ID allocator is behind existing id \(raw)"
        case .plateOrder(let b): "Floor plates of building \(b) are unsorted or duplicated"
        case .roomWithoutFloor(let r): "Room \(r) is not on built floors"
        case .overlappingRooms(let a, let b): "Rooms \(a) and \(b) overlap"
        case .invalidStanding(let b): "Building \(b) has an invalid class or reputation"
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
            let s = b.standing
            guard s.classLevel >= 0, (0...100).contains(s.reputation), s.promotions.count == s.classLevel,
                  s.promotions == s.promotions.sorted() else { throw WorldIntegrityError.invalidStanding(b.id) }
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
        for person in people {
            maxID = max(maxID, person.id.raw)
            guard buildings.contains(person.buildingID) else {
                throw WorldIntegrityError.danglingReference("person \(person.id) → building \(person.buildingID)")
            }
            for room in [person.homeRoom, person.workRoom].compactMap({ $0 }) where !rooms.contains(room) {
                throw WorldIntegrityError.danglingReference("person \(person.id) → room \(room)")
            }
        }
        var leased = Set<RoomID>()
        for tenant in tenants {
            maxID = max(maxID, tenant.id.raw)
            guard let room = rooms[tenant.room], room.buildingID == tenant.buildingID else {
                throw WorldIntegrityError.danglingReference("tenant \(tenant.id) → room \(tenant.room)")
            }
            guard leased.insert(tenant.room).inserted else {
                throw WorldIntegrityError.danglingReference("room \(tenant.room) leased twice")
            }
        }
        for person in people {
            if let t = person.tenantID, !tenants.contains(t) {
                throw WorldIntegrityError.danglingReference("person \(person.id) → tenant \(t)")
            }
        }
        for u in upkeep where !rooms.contains(u.id) {
            throw WorldIntegrityError.danglingReference("upkeep → room \(u.id)")
        }
        for job in facilities.jobs {
            guard rooms.contains(job.room) else { throw WorldIntegrityError.danglingReference("job → room \(job.room)") }
            if let a = job.assignee, people[a]?.job?.room != job.room {
                throw WorldIntegrityError.danglingReference("job in \(job.room) → staff \(a)")
            }
        }
        for car in elevators {
            guard let shaft = rooms[car.id], shaft.buildingID == car.buildingID, shaft.floors.contains(car.floor) else {
                throw WorldIntegrityError.danglingReference("elevator \(car.id) → shaft")
            }
            for id in car.passengers {
                guard case let .riding(ride, _)? = people[id]?.place, ride.shaft == car.id else {
                    throw WorldIntegrityError.danglingReference("elevator \(car.id) → passenger \(id)")
                }
            }
        }
        for person in people {
            if case let .riding(ride, _) = person.place, elevators[ride.shaft]?.passengers.contains(person.id) != true {
                throw WorldIntegrityError.danglingReference("rider \(person.id) → elevator \(ride.shaft)")
            }
        }
        guard ids.next > maxID else { throw WorldIntegrityError.idAllocatorBehind(maxID) }
    }
}
