import Foundation
import SkylineCore

/// Taxes (Phase E): property tax per building on its assessed value, and profit tax on the
/// daily closing's result. Both are booked in the ledger category `taxes`.
public enum Taxes {
    /// What the building cost to build: every plate and every room at today's construction
    /// prices (content costs × the city's construction level).
    public static func assessedValue(_ building: Building, world: GameWorld, catalog: BuildCatalog) -> Int {
        let rules = catalog.rules
        var value = 0
        for plate in building.floors {
            value += (plate.level < 0 ? rules.basementSlabCostPerModule : rules.slabCostPerModule) * plate.span.count
        }
        for room in world.rooms(in: building.id) {
            value += (catalog.spec(room.definitionID)?.costPerModule ?? 0) * room.columns.count * room.floors.count
        }
        return Int((Double(value) * (world.city(of: building.id)?.economy.construction ?? 1)).rounded())
    }

    /// Property tax of one building per closing.
    public static func propertyTax(_ building: Building, world: GameWorld, catalog: BuildCatalog, rules: EconomyRules) -> Int {
        guard let rate = rules.propertyTaxRate, rate > 0 else { return 0 }
        let level = world.city(of: building.id)?.economy.tax ?? 1
        return Int((Double(assessedValue(building, world: world, catalog: catalog)) * rate * level).rounded())
    }
}

extension SimulationEngine {
    /// Profit tax on what the closing booked since `before` (the day's totals when it began:
    /// wages, rent, turnover, running costs, property tax, interest). Nothing on a loss.
    func postProfitTax(since before: DayTotals, at now: Tick, world: inout GameWorld) {
        guard let rate = rules.economy?.profitTaxRate, rate > 0 else { return }
        let after = world.ledger.totals(onDay: SimClock.day(now))
        let result = zip(after.amounts, before.amounts).reduce(0) { $0 + $1.0 - $1.1 }
        let tax = Int((Double(result) * rate).rounded())
        guard tax > 0 else { return }
        world.ledger.post(Transaction(tick: now, amount: -tax, category: .taxes,
                                      detail: "Profit tax — \(Int((rate * 100).rounded())) % of \(result)"))
    }
}
