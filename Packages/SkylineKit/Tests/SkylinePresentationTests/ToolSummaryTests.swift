import Testing
import SkylineCore
import SkylineContent
@testable import SkylinePresentation

/// The bar above the palette names the picked tool and its price (0.30.3).
@Suite struct ToolSummaryTests {
    @Test func namesAndPricesTheTool() throws {
        let lib = try ContentLibrary.loadBase()
        let game = try NewGameFactory.make(startID: NewGameFactory.defaultStartID, library: lib)
        let b = try #require(game.world.buildings(on: game.activePropertyID).first)
        let factor = try #require(game.world.city(of: b.id)).economy.construction
        func summary(_ tool: ConstructionTool, detail: String? = nil) throws -> ToolSummary {
            try #require(ToolSummary.make(tool: tool, world: game.world, propertyID: game.activePropertyID, catalog: lib.buildCatalog, detail: detail))
        }
        let service = try summary(.room("service-elevator"), detail: "staff only")
        let spec = try #require(lib.buildCatalog.spec("service-elevator"))
        #expect(service.title == "Service Elevator" && service.detail == "staff only")
        let from = Money.format(Int((Double(spec.costPerModule * spec.minWidth * spec.minFloors) * factor).rounded()))
        #expect(service.line.contains("from \(from)") && service.line.contains("per floor"))
        let hotel = try summary(.room("hotel-single"))
        #expect(hotel.title == "Hotel Single Room" && hotel.line.contains("6–7 m wide"))
        // A room two floors high pays each extra metre on both floors.
        let base = lib.buildCatalog
        let hall = RoomSpec(id: "tall-hall", name: "Hall", category: "office", kind: .room, appearance: "office",
                            minWidth: 6, maxWidth: 12, minFloors: 2, maxFloors: 2, costPerModule: 1000)
        let tall = try #require(ToolSummary.make(tool: .room("tall-hall"), world: game.world, propertyID: game.activePropertyID,
                                                 catalog: BuildCatalog(rules: base.rules, specs: base.specs + [hall], classes: base.classes)))
        #expect(tall.line.contains("\(Money.format(Int((2000 * factor).rounded()))) per"))
        #expect(try summary(.floor).title == "Floor")
        #expect(try summary(.demolish).line.contains("%"))
        #expect(ToolSummary.make(tool: .room("nope"), world: game.world, propertyID: game.activePropertyID, catalog: lib.buildCatalog) == nil)
    }

    /// Look-alike tools have their own palette icons (content `icon`).
    @Test func lookAlikeToolsHaveTheirOwnIcons() throws {
        let catalog = try ContentLibrary.loadBase().buildCatalog
        let elevators = ["elevator-shaft", "elevator-express", "service-elevator"].compactMap { catalog.spec($0) }
        let hotels = ["hotel-single", "hotel-twin", "hotel-suite"].compactMap { catalog.spec($0) }
        #expect(Set(elevators.map { $0.icon ?? $0.appearance }).count == 3)
        #expect(Set(hotels.map { $0.icon ?? $0.appearance }).count == 3)
    }
}
