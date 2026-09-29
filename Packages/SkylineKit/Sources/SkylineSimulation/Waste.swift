import Foundation
import SkylineCore

/// Waste and energy prices (Phase E).
///
/// Every resident and worker, and every amenity customer, leaves waste. The building's
/// waste rooms hold a limited amount per day for collection, which is billed per kg; what
/// does not fit is left lying around and dirties every room of the building.
public enum Waste {
    /// Kg per day: residents and workers, plus yesterday's amenity customers.
    public static func produced(in building: BuildingID, world: GameWorld, rules: SimulationRules) -> Double {
        guard let f = rules.facilities, let perPerson = f.wastePerPersonPerDay else { return 0 }
        let occupants = world.people.values.reduce(0) { $0 + ($1.buildingID == building && ($1.role == .worker || $1.role == .resident) ? 1 : 0) }
        let visits = world.tenants.values.reduce(0) { $0 + ($1.buildingID == building ? $1.sales?.lastVisits ?? 0 : 0) }
        return Double(occupants) * perPerson + Double(visits) * (f.wastePerVisit ?? 0)
    }

    /// Kg per day the building's waste rooms can take.
    public static func capacity(of building: BuildingID, world: GameWorld, catalog: BuildCatalog) -> Double {
        world.rooms(in: building).reduce(0) { $0 + (catalog.spec($1.definitionID)?.wasteCapacityPerModule ?? 0) * Double($1.columns.count) }
    }
}

extension SimulationEngine {
    /// Today's energy price of a city (a multiplier on utilities and lighting).
    func energyPrice(_ city: City?) -> Double {
        city?.energyPrice ?? city?.economy.energy ?? 1
    }

    /// Daily closing (from `closeDay`): collection is billed for what the waste rooms take;
    /// the overflow dirties the building's rooms in proportion.
    func collectWaste(at now: Tick, world: inout GameWorld) {
        guard let f = rules.facilities, f.wastePerPersonPerDay != nil else { return }
        let price = rules.economy?.wastePricePerKg ?? 0
        for building in world.buildings.values {
            let produced = Waste.produced(in: building.id, world: world, rules: rules)
            guard produced > 0 else { continue }
            let capacity = Waste.capacity(of: building.id, world: world, catalog: catalog)
            let collected = min(produced, capacity)
            let cost = Int((collected * price).rounded())
            if cost > 0 {
                world.ledger.post(Transaction(tick: now, amount: -cost, category: .waste,
                                              detail: "Waste collection — \(Int(collected.rounded())) kg, \(building.name)", building: building.id))
            }
            let overflow = (produced - collected) / produced
            let dirt = overflow * (f.overflowDirtPerDay ?? 0)
            guard dirt > 0 else { continue }
            for room in world.rooms(in: building.id) where catalog.spec(room.definitionID)?.kind == .room {
                world.upkeep.update(room.id) { $0.cleanliness = max(0, $0.cleanliness - dirt) }
            }
        }
    }

    /// Morning step: each city's energy price moves randomly around its base level and is
    /// pulled back toward it (deterministic per city and day), within half to twice the base.
    func advanceEnergyPrices(at now: Tick, world: inout GameWorld) {
        guard let economy = rules.economy, let volatility = economy.energyVolatility, volatility > 0 else { return }
        let reversion = economy.energyReversion ?? 0.3
        for city in world.cities.values {
            let base = city.economy.energy ?? 1
            let price = city.energyPrice ?? base
            var rng = SeededRandom(seed: city.seed, stream: 0xE9E_0000 &+ SimClock.day(now))
            let shock = (rng.unit() * 2 - 1) * volatility * base
            let next = min(max(price + reversion * (base - price) + shock, base / 2), base * 2)
            world.setEnergyPrice((next * 1000).rounded() / 1000, city: city.id)
        }
    }
}
