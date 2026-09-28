import Foundation
import SkylineCore

/// Lighting energy (Phase 12): metered at every hourly market step from the same lighting
/// model the renderer draws, and billed at the daily closing (`closeDay`).
public enum Energy {
    /// Current lighting load of a building in watts: every room's level from occupancy, time
    /// of day and its electricity supply.
    public static func lightingWatts(of building: BuildingID, world: GameWorld, engine: SimulationEngine,
                                     occupied: Set<RoomID>? = nil) -> Double {
        let occupied = occupied ?? Lighting.occupiedRooms(world)
        let service = engine.rules.facilities == nil ? nil
            : Utilities.allocate(building: building, world: world, catalog: engine.catalog, rules: engine.rules)
        let sod = SimClock.secondOfDay(world.clock.tick)
        return world.rooms(in: building).reduce(0) { sum, room in
            guard let spec = engine.catalog.spec(room.definitionID)?.lighting else { return sum }
            let power = service?.served[room.id]?["electricity"] ?? 1
            let level = Lighting.level(spec, room: room.id, occupied: occupied.contains(room.id), secondOfDay: sod, power: power)
            return sum + Lighting.watts(spec, room: room, level: level)
        }
    }
}

extension SimulationEngine {
    /// Adds one hour at the current lighting load to every building's meter.
    func meterLighting(at now: Tick, world: inout GameWorld) {
        guard rules.economy?.lightingPricePerKWh != nil else { return }
        let occupied = Lighting.occupiedRooms(world)
        for building in world.buildings.values {
            let watts = Energy.lightingWatts(of: building.id, world: world, engine: self, occupied: occupied)
            world.setLightingEnergy(building.lightingKWh + watts / 1000, building: building.id)
        }
    }
}
