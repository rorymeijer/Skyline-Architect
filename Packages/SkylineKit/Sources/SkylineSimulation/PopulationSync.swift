import Foundation
import SkylineCore

/// Keeps the population consistent with the building: every room whose spec has an
/// occupancy gets that many workers or residents; people whose room disappeared leave.
/// Phase 4 stand-in for tenants (Phase 8 adds choice, rent and vacancy).
public enum PopulationSync {
    @discardableResult
    public static func sync(_ world: inout GameWorld, catalog: BuildCatalog, rules: SimulationRules) -> (added: Int, removed: Int) {
        let now = world.clock.tick
        var removed = 0
        // People whose anchor room is gone leave immediately.
        for person in world.people.values where person.anchorRoom.map({ !world.rooms.contains($0) }) ?? true {
            world.people.remove(person.id)
            removed += 1
        }
        // Anyone standing in or heading to a removed room is sent outside.
        for person in world.people.values {
            var p = person
            switch p.place {
            case .room(let r, _) where !world.rooms.contains(r):
                p.place = .outside
            case .travelling(_, .room(let r, _)) where !world.rooms.contains(r):
                p.place = .outside
                p.nextGoal = p.anchorRoom != nil ? (p.role == .worker ? .work : .home) : nil
                p.nextEventTick = now
            default:
                continue
            }
            world.people.update(p.id) { $0 = p }
        }

        var countByRoom: [RoomID: [PersonID]] = [:]
        for p in world.people { if let r = p.anchorRoom { countByRoom[r, default: []].append(p.id) } }

        var added = 0
        for room in world.rooms.values {
            guard let occupancy = catalog.spec(room.definitionID)?.occupancy,
                  let schedule = rules.defaultSchedule(for: occupancy.role) else { continue }
            let want = occupancy.count(modules: room.columns.count)
            let have = countByRoom[room.id] ?? []
            if have.count > want {
                for id in have.suffix(have.count - want) { world.people.remove(id); removed += 1 }
            } else if have.count < want {
                for _ in 0..<(want - have.count) {
                    let id = world.makePersonID()
                    var rng = SeededRandom(seed: UInt64(id.raw), stream: 0x9E0)
                    let traits = UInt32(truncatingIfNeeded: rng.next())
                    let name = rules.names.first[rng.int(in: 0..<rules.names.first.count)] + " "
                        + rules.names.last[rng.int(in: 0..<rules.names.last.count)]
                    let age = occupancy.role == .worker ? rng.int(in: 21..<66) : rng.int(in: 18..<86)
                    var person = Person(id: id, name: name, age: age, role: occupancy.role, scheduleID: schedule.id,
                                        buildingID: room.buildingID,
                                        homeRoom: occupancy.role == .resident ? room.id : nil,
                                        workRoom: occupancy.role == .worker ? room.id : nil,
                                        place: .outside, nextEventTick: now, nextGoal: nil, traits: traits)
                    if occupancy.role == .resident {
                        // New residents move in right away.
                        person.nextGoal = .home
                        person.nextEventTick = now + Tick(rng.int(in: 0..<600))
                    } else if let next = rules.nextScheduled(after: now, schedule: schedule, traits: traits) {
                        person.nextGoal = next.goal
                        person.nextEventTick = next.tick
                    }
                    world.people.insert(person)
                    added += 1
                }
            }
        }
        return (added, removed)
    }
}
