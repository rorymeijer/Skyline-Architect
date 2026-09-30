import Foundation

/// Shafts in front of rooms (0.30, D-063): a stairwell or elevator shaft may stand in front of
/// rooms, which stay whole behind it (before 0.30 they made way and got narrower). Only a
/// space of the same kind blocks: a room another room, a shaft another shaft.
extension ConstructionEngine {
    /// The first space of `kind` in the way at `columns` × `floors` (a space of unknown type
    /// always blocks).
    func clash(kind: RoomKind, building b: BuildingID, columns: ColumnSpan, floors: FloorSpan, except: RoomID?,
               _ world: GameWorld) -> Room? {
        world.rooms.first {
            $0.buildingID == b && $0.id != except && $0.overlaps(columns: columns, floors: floors)
                && (catalog.spec($0.definitionID)?.kind ?? kind) == kind
        }
    }

    func validateResize(_ id: RoomID, _ floors: FloorSpan, _ world: GameWorld) -> Result<ConstructionPlan, ConstructionError> {
        guard let room = world.rooms[id] else { return .failure(.unknownRoom) }
        guard let spec = catalog.spec(room.definitionID) else { return .failure(.unknownDefinition(room.definitionID)) }
        guard spec.kind == .shaft else { return .failure(.notResizable) }
        guard floors != room.floors else { return .failure(.nothingToBuild) }
        guard floors.lowest <= room.floors.highest, room.floors.lowest <= floors.highest else { return .failure(.notContiguous) }
        guard floors.count >= spec.minFloors, floors.count <= spec.maxFloors else {
            return .failure(.heightOutOfRange(min: spec.minFloors, max: spec.maxFloors))
        }
        if let lo = spec.lowestLevel, floors.lowest < lo { return .failure(.levelNotAllowed) }
        if let hi = spec.highestLevel, floors.highest > hi { return .failure(.levelNotAllowed) }
        guard let building = world.buildings[room.buildingID] else { return .failure(.unknownBuilding) }
        for level in floors.lowest...floors.highest {
            guard let plate = building.plate(at: level), plate.span.contains(room.columns) else { return .failure(.noFloor(level: level)) }
        }
        if let clash = clash(kind: .shaft, building: room.buildingID, columns: room.columns, floors: floors, except: id, world) {
            return .failure(.overlaps(clash.id))
        }
        let old = Set(room.floors.lowest...room.floors.highest), new = Set(floors.lowest...floors.highest)
        let perFloor = spec.costPerModule * room.columns.count, factor = world.city(of: room.buildingID)?.economy.construction ?? 1
        let added = Self.scaled(perFloor * new.subtracting(old).count, factor)
        let removed = Self.scaled(perFloor * old.subtracting(new).count, factor)
        let cost = added - Int((Double(removed) * catalog.rules.demolitionRefund).rounded())
        return .success(ConstructionPlan(cost: cost, buildingID: room.buildingID, columns: room.columns,
                                         floors: FloorSpan(lowest: min(floors.lowest, room.floors.lowest), highest: max(floors.highest, room.floors.highest))))
    }

    /// Validates a batch on a scratch copy, step by step (later steps see earlier ones).
    func validateBatch(_ commands: [BuildCommand], _ world: GameWorld) -> Result<ConstructionPlan, ConstructionError> {
        var scratch = world
        var total: ConstructionPlan?
        for command in commands {
            let plan: ConstructionPlan
            switch validate(command, in: scratch) {
            case .success(let p): plan = p
            case .failure(let e): return .failure(e)
            }
            _ = try? apply(command, to: &scratch)
            if let t = total {
                total = ConstructionPlan(cost: t.cost + plan.cost, buildingID: t.buildingID, columns: Self.union(t.columns, plan.columns),
                                         floors: FloorSpan(lowest: min(t.floors.lowest, plan.floors.lowest), highest: max(t.floors.highest, plan.floors.highest)))
            } else {
                total = plan
            }
        }
        guard let total else { return .failure(.nothingToBuild) }
        return .success(total)
    }
}
