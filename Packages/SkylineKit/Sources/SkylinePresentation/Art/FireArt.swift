import Foundation
import SkylineCore

/// A burning room as the renderer draws it (Phase 14).
public struct FlameMark: Hashable, Sendable {
    public var rect: Rect
    public var intensity: Double
    /// 0.7…1: flicker at this instant (deterministic in game time).
    public var flicker: Double
    /// Sprinklers are spraying in this room.
    public var sprinklers: Bool
}

/// A fire-damaged room: soot darkens it until it is repaired.
public struct ScorchMark: Hashable, Sendable {
    public var rect: Rect
    /// 0…1.
    public var soot: Double
}

public enum FireView {
    /// Burning rooms of the property at (fractional) tick `time`.
    /// `protected` are the rooms covered by working sprinklers (from the simulation).
    public static func flames(world: GameWorld, propertyID: PropertyID, time: Double, protected: Set<RoomID> = []) -> [FlameMark] {
        let buildings = Set(world.buildings(on: propertyID).map(\.id))
        var out: [FlameMark] = []
        for fire in world.incidents.fires where buildings.contains(fire.building) {
            for b in fire.burning {
                guard let room = world.rooms[b.room] else { continue }
                let phase = Double(b.room.raw % 17)
                let flicker = 0.85 + 0.1 * sin(time * 2.3 + phase) + 0.05 * sin(time * 5.7 + phase * 2)
                out.append(FlameMark(rect: world.grid.rect(columns: room.columns, floors: room.floors), intensity: b.intensity, flicker: flicker,
                                     sprinklers: protected.contains(b.room)))
            }
        }
        return out
    }

    /// Rooms a fire reached that are still damaged (condition below 0.5): the lower the
    /// condition, the more soot.
    public static func scorched(world: GameWorld, propertyID: PropertyID) -> [ScorchMark] {
        let buildings = Set(world.buildings(on: propertyID).map(\.id))
        var seen = Set<RoomID>()
        var out: [ScorchMark] = []
        for incident in world.incidents.log where incident.kind == "fire" && buildings.contains(incident.building) {
            for id in incident.rooms where seen.insert(id).inserted {
                guard let room = world.rooms[id], let condition = world.upkeep[id]?.condition, condition < 0.5 else { continue }
                out.append(ScorchMark(rect: world.grid.rect(columns: room.columns, floors: room.floors), soot: min(1, (0.5 - condition) * 2.2)))
            }
        }
        return out
    }

    /// Where fire engines stand once the brigade has arrived: at the kerb left of each
    /// burning building (world position of the engine's rear, at grade).
    public static func engines(world: GameWorld, propertyID: PropertyID, time: Double) -> [Vec2] {
        world.incidents.fires.compactMap { fire in
            guard time >= Double(fire.brigadeArrives), let b = world.buildings[fire.building], b.propertyID == propertyID else { return nil }
            return Vec2(world.grid.x(ofColumn: b.footprint.start) - 11, 0)
        }
    }
}
