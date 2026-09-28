import Foundation
import SkylineCore

public enum EstateError: Error, Equatable, CustomStringConvertible {
    case unknownPlot(String)
    case alreadyOwned(String)
    case notForSale(String)
    case insufficientFunds(needed: Int, available: Int)

    public var description: String {
        switch self {
        case .unknownPlot(let id): "Unknown plot \(id)"
        case .alreadyOwned(let id): "Plot \(id) is already yours"
        case .notForSale(let id): "Plot \(id) is not for sale"
        case .insufficientFunds(let n, let a): "The plot costs $\(n); you have $\(a)"
        }
    }
}

/// A plot the player could buy (Phase 15).
public struct PlotOffer: Equatable, Sendable {
    public var plot: PlotDefinition
    public var city: CityDefinition
    public var price: Int
}

/// Owning land in several cities (Phase 15): what is for sale, buying it, and matching
/// properties of older saves to their plots. Land purchases are not construction: they are
/// posted to the ledger (`land`) and cannot be undone.
public enum Estate {
    /// Plots with a price that the player does not own yet, in content order.
    public static func offers(world: GameWorld, library: ContentLibrary) -> [PlotOffer] {
        let owned = Set(world.properties.values.compactMap(\.plotID))
        return library.orderedPlots.compactMap { plot in
            guard let price = plot.price, !owned.contains(plot.id), let city = library.city(plot.cityID) else { return nil }
            return PlotOffer(plot: plot, city: city, price: price)
        }
    }

    /// Buys a plot: the city joins the estate if needed, the property is added with the
    /// plot's foundation, and the price is paid. Nothing changes if it fails.
    @discardableResult
    public static func buy(_ plotID: String, world: inout GameWorld, library: ContentLibrary) throws -> PropertyID {
        guard let plot = library.plot(plotID), let cityDef = library.city(plot.cityID) else { throw EstateError.unknownPlot(plotID) }
        guard !world.properties.values.contains(where: { $0.plotID == plotID }) else { throw EstateError.alreadyOwned(plotID) }
        guard let price = plot.price, let f = plot.foundation else { throw EstateError.notForSale(plotID) }
        guard world.ledger.cash >= price else { throw EstateError.insufficientFunds(needed: price, available: world.ledger.cash) }
        var w = world
        let cityID = w.cities.values.first { $0.definitionID == cityDef.id }?.id
            ?? w.addCity(definitionID: cityDef.id, name: cityDef.name, seed: cityDef.seed, economy: cityDef.economy ?? CityEconomy())
        let property = try w.addProperty(
            cityID: cityID, name: plot.name,
            plot: Plot(frontage: ColumnSpan(start: 0, count: plot.frontageModules), maxBasementFloors: plot.maxBasementFloors,
                       siteMargin: plot.siteMarginModules, strata: cityDef.geology),
            plotID: plot.id)
        try w.addBuilding(propertyID: property, name: f.buildingName,
                          footprint: ColumnSpan(start: f.footprintOffsetModules, count: f.footprintModules),
                          foundation: Foundation(basementFloors: f.basementFloors, pileDepth: f.pileDepthMeters, pileSpacing: f.pileSpacingModules))
        w.ledger.post(Transaction(tick: w.clock.tick, amount: -price, category: .land, detail: "Land — \(plot.name), \(cityDef.name)"))
        world = w
        return property
    }

    /// Older saves (before format 12): each property without a plot id is matched to the
    /// content plot of its city with the same name; the city takes its market from content.
    public static func adoptLegacy(_ world: inout GameWorld, library: ContentLibrary) {
        for property in world.properties.values where property.plotID == nil {
            guard let city = world.cities[property.cityID],
                  let plot = library.orderedPlots.first(where: { $0.cityID == city.definitionID && $0.name == property.name }) else { continue }
            world.setPlotID(plot.id, property: property.id)
        }
        for city in world.cities.values where city.economy == CityEconomy() {
            if let economy = library.city(city.definitionID)?.economy, economy != city.economy { world.setEconomy(economy, city: city.id) }
        }
    }
}
