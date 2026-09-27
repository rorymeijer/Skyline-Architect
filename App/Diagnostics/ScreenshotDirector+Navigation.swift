#if DEBUG
import Foundation
import SkylineCore
import SkylineSimulation

/// Scenario helpers for the Phase 5 (navigation) captures.
extension ScreenshotDirector {
    /// Demo tower extended to floor 12; the new floors are served only by a second stairwell
    /// from floor 8, so every trip above floor 8 transfers there. Returns the new stairwell.
    static func buildTransferExtension(_ model: AppModel) -> RoomID? {
        guard let world = model.world, let property = model.activePropertyID,
              let building = world.buildings(on: property).first else { return nil }
        let b = building.id, x0 = building.footprint.start
        if let apartment = world.rooms(in: b).first(where: { $0.floors.lowest == 8 && $0.definitionID == "apartment-studio" }) {
            model.perform(.demolishRoom(apartment.id))
        }
        for level in 9...12 {
            model.perform(.buildFloor(building: b, level: level, span: ColumnSpan(start: x0 + 4, count: 24)))
        }
        model.perform(.placeRoom(building: b, definition: "stairs", columns: ColumnSpan(start: x0 + 21, count: 4),
                                 floors: FloorSpan(lowest: 8, highest: 12)))
        // Columns 4–8 stay free on the new floors for a replacement stairwell (step 04).
        for level in 9...12 {
            model.perform(.placeRoom(building: b, definition: level.isMultiple(of: 2) ? "apartment-studio" : "office-small",
                                     columns: ColumnSpan(start: x0 + 8, count: 10), floors: FloorSpan(lowest: level, highest: level)))
        }
        return model.world?.room(in: b, column: x0 + 21, floor: 8)?.id
    }

    static let replacementColumn = 4

    /// Places a stairwell for floors 8–12 at footprint column 4, replacing the floor-8
    /// plant room there (replacement shaft on the other side of the core).
    static func placeReplacementStairs(_ model: AppModel) -> RoomID? {
        guard let world = model.world, let property = model.activePropertyID,
              let building = world.buildings(on: property).first else { return nil }
        let x = building.footprint.start + replacementColumn
        if let plant = world.room(in: building.id, column: x, floor: 8) { model.perform(.demolishRoom(plant.id)) }
        model.perform(.placeRoom(building: building.id, definition: "stairs", columns: ColumnSpan(start: x, count: 4),
                                 floors: FloorSpan(lowest: 8, highest: 12)))
        return model.world?.room(in: building.id, column: x, floor: 8)?.id
    }

    /// Travellers whose trip uses two or more different stair shafts.
    static func transfers(in world: GameWorld) -> Int {
        world.people.values.filter { p in
            guard case let .travelling(legs, _) = p.place else { return false }
            let shafts = legs.compactMap { if case let .stairs(s, _, _, _, _, _, _) = $0 { s } else { nil } }
            return Set(shafts).count >= 2
        }.count
    }

    /// Travellers whose remaining trip still uses `shaft`.
    static func people(routedVia shaft: RoomID, in world: GameWorld) -> Int {
        let now = world.clock.tick
        return world.people.values.filter { p in
            guard case let .travelling(legs, _) = p.place else { return false }
            return legs.contains { leg in
                if case let .stairs(s, _, _, _, _, _, end) = leg { return s == shaft && end > now }
                return false
            }
        }.count
    }

    /// People currently on a leg that uses `shaft`.
    static func people(onShaft shaft: RoomID, in world: GameWorld) -> Int {
        let now = world.clock.tick
        return world.people.values.filter { p in
            guard case let .travelling(legs, _) = p.place, let leg = legs.first(where: { now < $0.end }),
                  case let .stairs(s, _, _, _, _, _, _) = leg else { return false }
            return s == shaft
        }.count
    }

    /// Position of someone walking across `floor` between two stair legs (a transfer walk).
    static func transferWalker(on floor: Int, in world: GameWorld) -> Vec2? {
        let now = world.clock.tick
        for p in world.people {
            guard case let .travelling(legs, _) = p.place,
                  let i = legs.firstIndex(where: { now < $0.end }), i > 0, i + 1 < legs.count,
                  case .walk(floor, _, _, _, _) = legs[i],
                  case .stairs = legs[i - 1], case .stairs = legs[i + 1],
                  let s = PersonMotion.sample(legs, at: Double(now), grid: world.grid) else { continue }
            return s.position
        }
        return nil
    }
}
#endif
