import Foundation

/// Shafts over rooms (0.20.2): a stairwell or elevator shaft may be placed or extended over
/// rooms, which make way instead of blocking it. A room loses the shaft's columns and keeps
/// its widest remaining side; a piece on the other side that is still wide enough becomes a
/// second (vacant) room of the same type. Tenants, people and upkeep stay with the room.
extension ConstructionEngine {
    /// How one room makes way: its new columns and any split-off piece.
    struct Trim: Equatable, Sendable {
        var room: Room
        var kept: ColumnSpan
        var pieces: [ColumnSpan]
    }

    /// The rooms in the way of a shaft at `columns` × `floors`, and how each makes way.
    /// Fails on another shaft in the way, or a room that would be left too narrow.
    func makeWay(building b: BuildingID, columns: ColumnSpan, floors: FloorSpan, except: RoomID?,
                 _ world: GameWorld) -> Result<[Trim], ConstructionError> {
        var trims: [Trim] = []
        for other in world.rooms.values where other.buildingID == b && other.id != except && other.overlaps(columns: columns, floors: floors) {
            guard let spec = catalog.spec(other.definitionID), spec.kind == .room else { return .failure(.overlaps(other.id)) }
            let left = ColumnSpan(start: other.columns.start, count: max(0, min(columns.start, other.columns.end) - other.columns.start))
            let right = ColumnSpan(start: max(columns.end, other.columns.start), count: max(0, other.columns.end - max(columns.end, other.columns.start)))
            let fitting = [left, right].filter { $0.count >= max(spec.minWidth, 1) }
            // The wider side keeps the room (the left one on a tie).
            guard let kept = fitting.count == 2 ? (right.count > left.count ? right : left) : fitting.first else {
                return .failure(.noSpaceLeft(room: spec.name))
            }
            trims.append(Trim(room: other, kept: kept, pieces: fitting.filter { $0 != kept }))
        }
        return .success(trims)
    }

    /// The plan of a shaft change: its own cost, and a region covering every room that moves.
    func shaftPlan(cost: Int, building b: BuildingID, columns: ColumnSpan, floors: FloorSpan, trims: [Trim]) -> ConstructionPlan {
        var cols = columns, lo = floors.lowest, hi = floors.highest
        for t in trims {
            cols = Self.union(cols, t.room.columns)
            lo = min(lo, t.room.floors.lowest)
            hi = max(hi, t.room.floors.highest)
        }
        return ConstructionPlan(cost: cost, buildingID: b, columns: cols, floors: FloorSpan(lowest: lo, highest: hi))
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
        let trims: [Trim]
        switch makeWay(building: room.buildingID, columns: room.columns, floors: floors, except: id, world) {
        case .success(let t): trims = t
        case .failure(let e): return .failure(e)
        }
        let old = Set(room.floors.lowest...room.floors.highest), new = Set(floors.lowest...floors.highest)
        let perFloor = spec.costPerModule * room.columns.count, factor = world.city(of: room.buildingID)?.economy.construction ?? 1
        let added = Self.scaled(perFloor * new.subtracting(old).count, factor)
        let removed = Self.scaled(perFloor * old.subtracting(new).count, factor)
        let cost = added - Int((Double(removed) * catalog.rules.demolitionRefund).rounded())
        return .success(shaftPlan(cost: cost, building: room.buildingID, columns: room.columns,
                                  floors: FloorSpan(lowest: min(floors.lowest, room.floors.lowest), highest: max(floors.highest, room.floors.highest)),
                                  trims: trims))
    }

    /// Applies the trims; returns the commands that undo them (split-off pieces removed
    /// first, then the rooms restored).
    func applyTrims(_ trims: [Trim], to world: inout GameWorld) -> [BuildCommand] {
        var removePieces: [BuildCommand] = [], restore: [BuildCommand] = []
        for t in trims {
            world.rooms.update(t.room.id) { $0.columns = t.kept }
            restore.append(.restoreRoom(t.room))
            for piece in t.pieces {
                let id: RoomID = world.ids.make()
                world.rooms.insert(Room(id: id, buildingID: t.room.buildingID, definitionID: t.room.definitionID, columns: piece, floors: t.room.floors))
                removePieces.append(.demolishRoom(id))
            }
            // People standing in the room step aside, into what is left of it.
            let lo = world.grid.x(ofColumn: t.kept.start) + 0.4, hi = max(world.grid.x(ofColumn: t.kept.end) - 0.4, lo)
            for p in world.people.values {
                guard case let .room(r, x) = p.place, r == t.room.id, x < lo || x > hi else { continue }
                world.people.update(p.id) { $0.place = .room(r, x: min(max(x, lo), hi)) }
            }
        }
        return removePieces + restore
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
