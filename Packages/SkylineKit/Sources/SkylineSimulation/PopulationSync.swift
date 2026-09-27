import Foundation
import SkylineCore

/// Keeps people and tenants consistent with the building after construction or loading.
///
/// Since Phase 8 rooms are no longer filled automatically — tenants arrive through the
/// rental market (`Leasing`). This sync only: ends the leases of demolished units (their
/// people leave), sends people heading to a removed room outside, and adopts people from
/// pre-tenant saves (people without a tenant are grouped per room into a tenant of the
/// first type that rents that room type).
public enum PopulationSync {
    @discardableResult
    public static func sync(_ world: inout GameWorld, catalog: BuildCatalog, rules: SimulationRules) -> (added: Int, removed: Int) {
        let now = world.clock.tick
        let before = world.people.count
        // Leases of demolished units end.
        for tenant in world.tenants.values where !world.rooms.contains(tenant.room) {
            Leasing.moveOut(tenant.id, world: &world)
        }
        // People whose anchor room is gone leave immediately.
        for person in world.people.values where person.anchorRoom.map({ !world.rooms.contains($0) }) ?? true {
            leaveCar(person.id, &world)
            world.people.remove(person.id)
        }
        // Anyone standing in or heading to a removed room is sent outside.
        for person in world.people.values {
            var p = person
            switch p.place {
            case .room(let r, _) where !world.rooms.contains(r):
                p.place = .outside
            case .travelling(_, .room(let r, _)) where !world.rooms.contains(r),
                 .waiting(_, .room(let r, _), _) where !world.rooms.contains(r),
                 .riding(_, .room(let r, _)) where !world.rooms.contains(r):
                leaveCar(p.id, &world)
                p.place = .outside
                p.pendingRide = nil
                p.nextGoal = p.anchorRoom != nil ? (p.role == .worker ? .work : .home) : nil
                p.nextEventTick = now
            default:
                continue
            }
            world.people.update(p.id) { $0 = p }
        }
        adoptUntenanted(&world, catalog: catalog, rules: rules)
        return (0, before - world.people.count)
    }

    /// Pre-Phase-8 occupants: one tenant per room for people without a tenant.
    static func adoptUntenanted(_ world: inout GameWorld, catalog: BuildCatalog, rules: SimulationRules) {
        var byRoom: [RoomID: [PersonID]] = [:]
        var order: [RoomID] = []
        for p in world.people where p.tenantID == nil {
            guard let r = p.anchorRoom else { continue }
            if byRoom[r] == nil { order.append(r) }
            byRoom[r, default: []].append(p.id)
        }
        let leased = Set(world.tenants.values.map(\.room))
        for roomID in order {
            guard let room = world.rooms[roomID], let members = byRoom[roomID] else { continue }
            if let existing = world.tenants.values.first(where: { $0.room == roomID }) {
                for id in members { world.people.update(id) { $0.tenantID = existing.id } }
                continue
            }
            guard !leased.contains(roomID), let type = rules.tenantTypes(for: room.definitionID).first else { continue }
            let id = world.makeTenantID()
            let surname = world.people[members[0]]?.name.split(separator: " ").last.map(String.init) ?? "Resident"
            let name = type.kind == "business" ? "\(surname) & Co." : "\(surname) household"
            world.tenants.insert(Tenant(id: id, typeID: type.id, name: name, buildingID: room.buildingID, room: roomID,
                                        rent: Leasing.askingRent(room, world: world, catalog: catalog) ?? 0, since: world.clock.tick, satisfaction: 0.6))
            for pid in members { world.people.update(pid) { $0.tenantID = id } }
        }
    }

    private static func leaveCar(_ person: PersonID, _ world: inout GameWorld) {
        guard case let .riding(ride, _)? = world.people[person]?.place else { return }
        world.elevators.update(ride.shaft) { $0.passengers.removeAll { $0 == person } }
    }
}
