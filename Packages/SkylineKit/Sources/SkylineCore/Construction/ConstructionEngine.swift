import Foundation

/// Validates and applies `BuildCommand`s against the world using data-driven rules.
/// Pure and deterministic: no rendering, no UI, no global state.
public struct ConstructionEngine: Sendable {
    public let catalog: BuildCatalog

    public init(catalog: BuildCatalog) { self.catalog = catalog }

    // MARK: Validation

    public func validate(_ command: BuildCommand, in world: GameWorld) -> Result<ConstructionPlan, ConstructionError> {
        switch command {
        case let .buildFloor(b, level, span): validateBuildFloor(b, level, span, world)
        case let .demolishFloor(b, level): validateDemolishFloor(b, level, world)
        case let .placeRoom(b, def, columns, floors): validatePlaceRoom(b, def, columns, floors, world)
        case let .demolishRoom(id): validateDemolishRoom(id, world)
        case let .resizeRoom(id, floors): validateResize(id, floors, world)
        case let .batch(commands): validateBatch(commands, world)
        case let .extendFoundation(b, footprint, foundation): validateExtendFoundation(b, footprint, foundation, world)
        case let .restoreFoundation(b, footprint, _): validateRestoreFoundation(b, footprint, world)
        case let .restorePlate(b, level, plate):
            // Affected columns: everything covered before or after the restore.
            .success(ConstructionPlan(cost: 0, buildingID: b,
                                      columns: Self.union(plate?.span, world.buildings[b]?.plate(at: level)?.span),
                                      floors: FloorSpan(lowest: level, highest: level)))
        case let .restoreRoom(room):
            // Affected region: the room as restored and as it is now (if it exists).
            .success(ConstructionPlan(cost: 0, buildingID: room.buildingID, columns: Self.union(room.columns, world.rooms[room.id]?.columns),
                                      floors: FloorSpan(lowest: min(room.floors.lowest, world.rooms[room.id]?.floors.lowest ?? .max),
                                                        highest: max(room.floors.highest, world.rooms[room.id]?.floors.highest ?? .min))))
        }
    }

    static func union(_ a: ColumnSpan?, _ b: ColumnSpan?) -> ColumnSpan {
        switch (a, b) {
        case let (a?, b?):
            let lo = min(a.start, b.start), hi = max(a.end, b.end)
            return ColumnSpan(start: lo, count: hi - lo)
        case let (a?, nil): return a
        case let (nil, b?): return b
        default: return ColumnSpan(start: 0, count: 0)
        }
    }

    private func slabCost(level: Int, modules: Int, factor: Double) -> Int {
        Self.scaled(modules * (level < 0 ? catalog.rules.basementSlabCostPerModule : catalog.rules.slabCostPerModule), factor)
    }

    /// Local construction prices (Phase 15): costs are scaled by the city's market.
    private func costFactor(_ building: BuildingID, _ world: GameWorld) -> Double {
        world.city(of: building)?.economy.construction ?? 1
    }

    static func scaled(_ cost: Int, _ factor: Double) -> Int { factor == 1 ? cost : Int((Double(cost) * factor).rounded()) }

    private func refund(_ cost: Int) -> Int { -Int((Double(cost) * catalog.rules.demolitionRefund).rounded()) }

    private func validateBuildFloor(_ b: BuildingID, _ level: Int, _ span: ColumnSpan, _ world: GameWorld) -> Result<ConstructionPlan, ConstructionError> {
        guard let building = world.buildings[b] else { return .failure(.unknownBuilding) }
        guard span.count > 0 else { return .failure(.emptySpan) }
        var merged = span
        let existing = building.plate(at: level)
        if let existing {
            // Extending: the new span must touch or overlap the existing plate.
            guard span.start <= existing.span.end, existing.span.start <= span.end else { return .failure(.notContiguous) }
            let lo = min(span.start, existing.span.start), hi = max(span.end, existing.span.end)
            merged = ColumnSpan(start: lo, count: hi - lo)
            guard merged != existing.span else { return .failure(.nothingToBuild) }
        }
        if level < 0 {
            guard -level <= building.foundation.basementFloors else { return .failure(.noExcavation(level: level)) }
            guard building.footprint.contains(merged) else { return .failure(.outsideFootprint) }
        } else if level == 0 {
            guard building.footprint.contains(merged) else { return .failure(.outsideFootprint) }
        } else {
            if let max = world.restrictions?.maxFloor, level > max { return .failure(.aboveScenarioHeight(max: max)) }
            if let locked = lockedClass(floor: level, building: b, world) { return .failure(.locked(className: locked)) }
            guard let below = building.plate(at: level - 1) else { return .failure(.unsupported) }
            // The piles carry a limited height (0.21): longer piles, taller building.
            if let top = catalog.rules.highestLevel(for: building.foundation), level > top, let perMeter = catalog.rules.storeysPerPileMeter {
                return .failure(.pilesTooShort(needed: Double(level + 1) / perMeter))
            }
            let c = catalog.rules.maxCantileverModules
            let support = ColumnSpan(start: below.span.start - c, count: below.span.count + 2 * c)
            guard support.contains(merged) else { return .failure(.overhang(max: c)) }
        }
        let added = merged.count - (existing?.span.count ?? 0)
        return .success(ConstructionPlan(cost: slabCost(level: level, modules: added, factor: costFactor(b, world)), buildingID: b,
                                         columns: merged, floors: FloorSpan(lowest: level, highest: level)))
    }

    /// The class needed to build at `level`, if the building's class does not allow it yet.
    private func lockedClass(floor level: Int, building b: BuildingID, _ world: GameWorld) -> String? {
        let current = world.unlockedClass(of: b)
        guard current < catalog.classes.count, let max = catalog.classes[current].maxFloor, level > max else { return nil }
        return catalog.classAllowing(floor: level).map { catalog.classes[$0].name } ?? "a higher class"
    }

    private func validateDemolishFloor(_ b: BuildingID, _ level: Int, _ world: GameWorld) -> Result<ConstructionPlan, ConstructionError> {
        guard let building = world.buildings[b] else { return .failure(.unknownBuilding) }
        guard let plate = building.plate(at: level) else { return .failure(.noFloor(level: level)) }
        if world.rooms.contains(where: { $0.buildingID == b && $0.floors.contains(level) }) { return .failure(.floorNotEmpty) }
        // Floors carry the floor above; basements hang from the storey above them.
        let dependent = level >= 0 ? level + 1 : level - 1
        if building.plate(at: dependent) != nil { return .failure(.carriesFloorAbove) }
        return .success(ConstructionPlan(cost: refund(slabCost(level: level, modules: plate.span.count, factor: costFactor(b, world))), buildingID: b,
                                         columns: plate.span, floors: FloorSpan(lowest: level, highest: level)))
    }

    private func validatePlaceRoom(_ b: BuildingID, _ def: String, _ columns: ColumnSpan, _ floors: FloorSpan,
                                   _ world: GameWorld) -> Result<ConstructionPlan, ConstructionError> {
        guard let building = world.buildings[b] else { return .failure(.unknownBuilding) }
        guard let spec = catalog.spec(def) else { return .failure(.unknownDefinition(def)) }
        if world.restrictions?.forbids(def) == true { return .failure(.forbiddenInScenario) }
        if let needed = spec.unlockClass, needed > world.unlockedClass(of: b) {
            return .failure(.locked(className: catalog.classes.indices.contains(needed) ? catalog.classes[needed].name : "class \(needed)"))
        }
        guard columns.count >= spec.minWidth, columns.count <= spec.maxWidth else {
            return .failure(.widthOutOfRange(min: spec.minWidth, max: spec.maxWidth))
        }
        guard floors.count >= spec.minFloors, floors.count <= spec.maxFloors else {
            return .failure(.heightOutOfRange(min: spec.minFloors, max: spec.maxFloors))
        }
        if let lo = spec.lowestLevel, floors.lowest < lo { return .failure(.levelNotAllowed) }
        if let hi = spec.highestLevel, floors.highest > hi { return .failure(.levelNotAllowed) }
        for level in floors.lowest...floors.highest {
            guard let plate = building.plate(at: level) else { return .failure(.noFloor(level: level)) }
            guard plate.span.contains(columns) else { return .failure(.noFloor(level: level)) }
        }
        let cost = Self.scaled(spec.costPerModule * columns.count * floors.count, costFactor(b, world))
        if spec.kind == .shaft {
            // Rooms in the way make way; other shafts still block.
            switch makeWay(building: b, columns: columns, floors: floors, except: nil, world) {
            case .success(let trims): return .success(shaftPlan(cost: cost, building: b, columns: columns, floors: floors, trims: trims))
            case .failure(let e): return .failure(e)
            }
        }
        if let clash = world.rooms.first(where: { $0.buildingID == b && $0.overlaps(columns: columns, floors: floors) }) {
            return .failure(.overlaps(clash.id))
        }
        return .success(ConstructionPlan(cost: cost, buildingID: b, columns: columns, floors: floors))
    }

    private func validateDemolishRoom(_ id: RoomID, _ world: GameWorld) -> Result<ConstructionPlan, ConstructionError> {
        guard let room = world.rooms[id] else { return .failure(.unknownRoom) }
        guard !room.isPrivatelyOwned else { return .failure(.privatelyOwned) }
        let cost = Self.scaled((catalog.spec(room.definitionID)?.costPerModule ?? 0) * room.columns.count * room.floors.count,
                               costFactor(room.buildingID, world))
        return .success(ConstructionPlan(cost: refund(cost), buildingID: room.buildingID, columns: room.columns, floors: room.floors))
    }

    // MARK: Application

    /// Validates and applies `command`. On failure the world is unchanged.
    @discardableResult
    public func apply(_ command: BuildCommand, to world: inout GameWorld) throws -> AppliedConstruction {
        let plan = try validate(command, in: world).get()
        switch command {
        case let .buildFloor(b, level, _):
            let previous = world.buildings[b]?.plate(at: level)
            world.buildings.update(b) { $0.setPlate(FloorPlate(level: level, span: plan.columns), at: level) }
            return AppliedConstruction(plan: plan, inverse: .restorePlate(building: b, level: level, plate: previous))
        case let .demolishFloor(b, level):
            let previous = world.buildings[b]?.plate(at: level)
            world.buildings.update(b) { $0.setPlate(nil, at: level) }
            return AppliedConstruction(plan: plan, inverse: .restorePlate(building: b, level: level, plate: previous))
        case let .placeRoom(b, def, columns, floors):
            let trims = catalog.spec(def)?.kind == .shaft ? (try? makeWay(building: b, columns: columns, floors: floors, except: nil, world).get()) ?? [] : []
            let undoTrims = applyTrims(trims, to: &world)
            let id: RoomID = world.ids.make()
            world.rooms.insert(Room(id: id, buildingID: b, definitionID: def, columns: columns, floors: floors))
            let inverse: BuildCommand = undoTrims.isEmpty ? .demolishRoom(id) : .batch([.demolishRoom(id)] + undoTrims)
            return AppliedConstruction(plan: plan, inverse: inverse, createdRoom: id)
        case let .resizeRoom(id, floors):
            let previous = world.rooms[id]!
            let trims = (try? makeWay(building: previous.buildingID, columns: previous.columns, floors: floors, except: id, world).get()) ?? []
            let undoTrims = applyTrims(trims, to: &world)
            world.rooms.update(id) { $0.floors = floors }
            let inverse: BuildCommand = undoTrims.isEmpty ? .restoreRoom(previous) : .batch([.restoreRoom(previous)] + undoTrims)
            return AppliedConstruction(plan: plan, inverse: inverse)
        case let .extendFoundation(b, footprint, foundation), let .restoreFoundation(b, footprint, foundation):
            return AppliedConstruction(plan: plan, inverse: setFoundation(b, footprint: footprint, foundation: foundation, in: &world))
        case let .batch(commands):
            var inverses: [BuildCommand] = []
            for command in commands { inverses.append(try apply(command, to: &world).inverse) }
            return AppliedConstruction(plan: plan, inverse: .batch(inverses.reversed()))
        case let .demolishRoom(id):
            let room = world.rooms.remove(id)!
            return AppliedConstruction(plan: plan, inverse: .restoreRoom(room))
        case let .restorePlate(b, level, plate):
            guard world.buildings.contains(b) else { throw ConstructionError.unknownBuilding }
            let previous = world.buildings[b]?.plate(at: level)
            world.buildings.update(b) { $0.setPlate(plate, at: level) }
            return AppliedConstruction(plan: plan, inverse: .restorePlate(building: b, level: level, plate: previous))
        case let .restoreRoom(room):
            guard world.buildings.contains(room.buildingID) else { throw ConstructionError.unknownBuilding }
            // An existing room is changed in place (and restored as it was on undo).
            if let previous = world.rooms[room.id] {
                world.rooms.update(room.id) { $0 = room }
                return AppliedConstruction(plan: plan, inverse: .restoreRoom(previous))
            }
            world.rooms.insert(room)
            return AppliedConstruction(plan: plan, inverse: .demolishRoom(room.id))
        }
    }
}
