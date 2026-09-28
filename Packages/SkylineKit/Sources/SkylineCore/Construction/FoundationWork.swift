import Foundation

/// Extending foundations (0.21): wider (within the plot), deeper (more basement levels,
/// within the plot's limit) and longer piles, which carry more storeys when the content
/// sets `storeysPerPileMeter`. Foundations only grow; the exact inverse restores them.
extension ConstructionEngine {
    /// Piles across a footprint at the foundation's spacing (both edges included).
    static func pileCount(_ footprint: ColumnSpan, spacing: Int) -> Int {
        footprint.count / max(spacing, 1) + 1
    }

    /// What growing a foundation costs: new footprint modules (raft and walls), excavated
    /// basement volume (modules × levels) and pile meters, at local prices.
    func foundationCost(from old: (ColumnSpan, Foundation), to new: (ColumnSpan, Foundation), factor: Double) -> Int {
        let r = catalog.rules
        let widen = (new.0.count - old.0.count) * (r.foundationCostPerModule ?? 6000)
        let dig = (new.0.count * new.1.basementFloors - old.0.count * old.1.basementFloors) * (r.excavationCostPerModule ?? 4000)
        let meters = Double(Self.pileCount(new.0, spacing: new.1.pileSpacing)) * new.1.pileDepth
            - Double(Self.pileCount(old.0, spacing: old.1.pileSpacing)) * old.1.pileDepth
        let piles = Int((meters * Double(r.pileCostPerMeter ?? 150)).rounded())
        return Self.scaled(widen + dig + piles, factor)
    }

    func validateExtendFoundation(_ b: BuildingID, _ footprint: ColumnSpan, _ foundation: Foundation,
                                  _ world: GameWorld) -> Result<ConstructionPlan, ConstructionError> {
        guard let building = world.buildings[b], let plot = world.properties[building.propertyID]?.plot else { return .failure(.unknownBuilding) }
        let old = building.foundation
        guard footprint.contains(building.footprint), foundation.basementFloors >= old.basementFloors,
              foundation.pileDepth >= old.pileDepth, foundation.pileSpacing == old.pileSpacing else { return .failure(.foundationCanOnlyGrow) }
        guard footprint != building.footprint || foundation != old else { return .failure(.nothingToBuild) }
        guard plot.frontage.contains(footprint) else { return .failure(.outsidePlot) }
        if world.buildings(on: building.propertyID).contains(where: { $0.id != b && $0.footprint.overlaps(footprint) }) {
            return .failure(.footprintOverlapsBuilding)
        }
        guard foundation.basementFloors <= plot.maxBasementFloors else { return .failure(.basementTooDeep(allowed: plot.maxBasementFloors)) }
        let raftDepth = -foundation.raftBottomY(grid: world.grid)
        guard foundation.pileDepth > raftDepth else { return .failure(.pilesTooShort(needed: raftDepth + 1)) }
        let cost = foundationCost(from: (building.footprint, old), to: (footprint, foundation),
                                  factor: world.city(of: b)?.economy.construction ?? 1)
        return .success(ConstructionPlan(cost: cost, buildingID: b, columns: footprint,
                                         floors: FloorSpan(lowest: -foundation.basementFloors, highest: 0)))
    }

    func validateRestoreFoundation(_ b: BuildingID, _ footprint: ColumnSpan, _ world: GameWorld) -> Result<ConstructionPlan, ConstructionError> {
        guard let building = world.buildings[b] else { return .failure(.unknownBuilding) }
        return .success(ConstructionPlan(cost: 0, buildingID: b, columns: Self.union(footprint, building.footprint),
                                         floors: FloorSpan(lowest: -building.foundation.basementFloors, highest: 0)))
    }

    /// Sets a footprint and foundation; returns the command that puts back the old ones.
    func setFoundation(_ b: BuildingID, footprint: ColumnSpan, foundation: Foundation, in world: inout GameWorld) -> BuildCommand {
        let old = world.buildings[b]!
        world.buildings.update(b) {
            $0.footprint = footprint
            $0.foundation = foundation
        }
        return .restoreFoundation(building: b, footprint: old.footprint, foundation: old.foundation)
    }
}
