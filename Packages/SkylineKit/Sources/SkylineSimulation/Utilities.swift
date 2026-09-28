import Foundation
import SkylineCore

/// How well a building's rooms are supplied with each utility (Phase 10). Derived, never
/// saved: recomputed from rooms, equipment and upkeep whenever needed.
public struct UtilityService: Equatable, Sendable {
    /// Served fraction (0…1) per room and utility it uses.
    public var served: [RoomID: [String: Double]] = [:]
    /// Total supply and demand per utility.
    public var supply: [String: Double] = [:]
    public var demand: [String: Double] = [:]
    /// Equipment rooms that have failed (condition below the failure threshold).
    public var broken: [RoomID] = []

    /// Average served fraction over the utilities a room uses (1 if it uses none).
    public func score(_ room: RoomID) -> Double {
        guard let s = served[room], !s.isEmpty else { return 1 }
        return s.keys.sorted().reduce(0) { $0 + s[$1]! } / Double(s.count)     // fixed order: deterministic sum
    }

    /// The worst-served utility of a room (1 if it uses none): a unit without power is
    /// unusable even if its water is fine.
    public func minimum(_ room: RoomID) -> Double {
        served[room]?.values.min() ?? 1
    }

    /// Rooms missing some of a utility (served < 99 %).
    public func shortOf(_ utility: String) -> [RoomID] {
        served.filter { ($0.value[utility] ?? 1) < 0.99 }.map(\.key).sorted()
    }
}

/// Abstracted distribution: equipment rooms (`utilitySupply`, per module of width) serve
/// rooms within `utilityRange` floors. Consumers (`utilityDemand`, per module per floor) are
/// served lowest floor first; each draws from the nearest equipment in range with capacity
/// left (ties: lower id). Failed equipment supplies nothing.
public enum Utilities {
    public static func allocate(building: BuildingID, world: GameWorld, catalog: BuildCatalog, rules: SimulationRules) -> UtilityService {
        var service = UtilityService()
        guard let facilities = rules.facilities else { return service }
        let rooms = world.rooms(in: building).sorted { ($0.floors.lowest, $0.id) < ($1.floors.lowest, $1.id) }
        // One (hashed) spec lookup per room, not one per room and utility (Phase 19).
        let specs = rooms.map { catalog.spec($0.definitionID) }
        for (room, spec) in zip(rooms, specs) where spec?.utilitySupply != nil {
            if (world.upkeep[room.id]?.condition ?? 1) < facilities.failureBelow { service.broken.append(room.id) }
        }
        let broken = Set(service.broken)
        for utility in facilities.utilities.map(\.id) {
            var suppliers: [(room: Room, range: Int, left: Double)] = []
            for (room, spec) in zip(rooms, specs) {
                guard let spec, let perModule = spec.utilitySupply?[utility], perModule > 0 else { continue }
                let capacity = broken.contains(room.id) ? 0 : perModule * Double(room.columns.count)
                service.supply[utility, default: 0] += capacity
                suppliers.append((room, spec.utilityRange ?? 0, capacity))
            }
            // The order of suppliers depends only on the consumer's floor: computed once per floor.
            var orders: [Int: [Int]] = [:]
            for (room, spec) in zip(rooms, specs) {
                guard let perModule = spec?.utilityDemand?[utility], perModule > 0 else { continue }
                let need = perModule * Double(room.columns.count * room.floors.count)
                service.demand[utility, default: 0] += need
                var got = 0.0
                let floor = room.floors.lowest
                let order = orders[floor] ?? suppliers.indices
                    .filter { abs(suppliers[$0].room.floors.lowest - floor) <= suppliers[$0].range }
                    .sorted { a, b in
                        let da = abs(suppliers[a].room.floors.lowest - floor)
                        let db = abs(suppliers[b].room.floors.lowest - floor)
                        return (da, suppliers[a].room.id) < (db, suppliers[b].room.id)
                    }
                orders[floor] = order
                for i in order where got < need {
                    let take = min(suppliers[i].left, need - got)
                    suppliers[i].left -= take
                    got += take
                }
                service.served[room.id, default: [:]][utility] = need > 0 ? got / need : 1
            }
        }
        return service
    }
}
