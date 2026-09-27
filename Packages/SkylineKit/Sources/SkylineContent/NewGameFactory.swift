import Foundation
import SkylineCore

/// A freshly created game: the world plus which property the player starts looking at.
public struct NewGame: Sendable {
    public var world: GameWorld
    public var activePropertyID: PropertyID
    public var startID: String
}

/// Builds a `GameWorld` from content definitions.
public enum NewGameFactory {
    public static func make(startID: String, library: ContentLibrary) throws -> NewGame {
        guard let start = library.start(startID) else {
            throw ContentError(pack: library.manifest.id, file: "starts", message: "Unknown start '\(startID)'")
        }
        // References were validated at load time, so these lookups cannot fail.
        let cityDef = library.city(start.cityID)!
        let plotDef = library.plot(start.plotID)!

        var world = GameWorld(grid: .standard)
        world.unlocks = start.mode == .standard ? .byClass : .all
        let cityID = world.addCity(definitionID: cityDef.id, name: cityDef.name, seed: cityDef.seed)
        let plot = Plot(
            frontage: ColumnSpan(start: 0, count: plotDef.frontageModules),
            maxBasementFloors: plotDef.maxBasementFloors,
            siteMargin: plotDef.siteMarginModules,
            strata: cityDef.geology)
        let propertyID = try world.addProperty(cityID: cityID, name: start.propertyName, plot: plot)

        if let f = start.startingFoundation {
            try world.addBuilding(
                propertyID: propertyID,
                name: f.buildingName,
                footprint: ColumnSpan(start: f.footprintOffsetModules, count: f.footprintModules),
                foundation: Foundation(basementFloors: f.basementFloors, pileDepth: f.pileDepthMeters, pileSpacing: f.pileSpacingModules))
        }
        if let cash = start.startingCash, cash > 0 {
            world.ledger.post(Transaction(tick: 0, amount: cash, category: .grant, detail: "Starting capital"))
        }
        return NewGame(world: world, activePropertyID: propertyID, startID: start.id)
    }

    /// The default sandbox start used when the app launches directly into a game.
    public static let defaultStartID = "sandbox-quay"
    /// The standard game (unlocks by building class).
    public static let standardStartID = "standard-quay"
}
