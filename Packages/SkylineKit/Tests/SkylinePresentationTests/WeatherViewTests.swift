import Testing
import SkylineCore
import SkylineContent
@testable import SkylinePresentation

@Suite struct WeatherViewTests {
    let rules = try! ContentLibrary.loadBase().simulationRules.weather!

    func state(_ yesterday: String, _ today: String, _ t: Double = 15) -> WeatherState {
        WeatherState(day: 3, yesterday: yesterday, today: today, tomorrow: "clear", temperature: t)
    }

    /// 06:00 is tick 0 of each day; the look changes from yesterday's to today's by 06:45.
    @Test func lookFollowsTheWeatherAndChangesAfterSixAM() {
        let noon = 6.0 * 3600
        #expect(WeatherView.look(state: state("clear", "clear"), rules: rules, time: noon) == .clear)
        let rain = WeatherView.look(state: state("clear", "rain"), rules: rules, time: noon)
        #expect(rain.precipitation == .rain && rain.intensity == 0.6 && rain.wet == 1 && rain.cloud == 0.8)
        let early = WeatherView.look(state: state("clear", "rain"), rules: rules, time: 600)      // 06:10
        #expect(early.cloud > 0 && early.cloud < rain.cloud && early.intensity < rain.intensity)
        let snow = WeatherView.look(state: state("snow", "snow", -3), rules: rules, time: noon)
        #expect(snow.precipitation == .snow && snow.snowCover == 1)
        let after = WeatherView.look(state: state("snow", "clear", 1), rules: rules, time: noon)
        #expect(after.snowCover == 0.6 && after.precipitation == nil)                // it lies on in the cold
        #expect(WeatherView.look(state: state("snow", "clear", 9), rules: rules, time: noon).snowCover == 0)
        #expect(WeatherView.look(state: nil, rules: rules, time: noon) == .clear)
    }

    @Test func stormsFlashDeterministically() {
        let storm = state("storm", "storm")
        let flashes = stride(from: 21_600.0, to: 25_200, by: 0.5).map { WeatherView.look(state: storm, rules: rules, time: $0).lightning }
        #expect(flashes.contains { $0 > 0.9 })
        #expect(Double(flashes.filter { $0 > 0 }.count) / Double(flashes.count) < 0.05)
        #expect(flashes == stride(from: 21_600.0, to: 25_200, by: 0.5).map { WeatherView.look(state: storm, rules: rules, time: $0).lightning })
        #expect(WeatherView.look(state: state("rain", "rain"), rules: rules, time: 21_700).lightning == 0)
    }

    @Test func weatherShapesTheGradeAndTheLights() {
        let day = Grade.day
        let storm = WeatherView.look(state: state("storm", "storm"), rules: rules, time: 21_600)
        let grey = WeatherView.grade(day, look: storm)
        #expect(grey.top.r < 0.8 && abs(grey.top.r - grey.top.g) < 0.05)                // darker and grey
        let heat = WeatherView.grade(day, look: WeatherView.look(state: state("heat", "heat"), rules: rules, time: 21_600))
        #expect(heat.bottom.r > heat.bottom.b + 0.05)                                     // warm haze
        #expect(WeatherView.darkness(daylight: 1, look: storm) > 0.3)                    // lights on in a storm
        #expect(WeatherView.darkness(daylight: 1, look: .clear) == 0)
    }

    @Test func snowSettlesOnRoofsAndSetbacks() throws {
        let lib = try ContentLibrary.loadBase()
        var game = try NewGameFactory.make(startID: NewGameFactory.defaultStartID, library: lib)
        let b = game.world.buildings(on: game.activePropertyID).first!
        for c in lib.blueprint("demo-tower")!.commands(for: b) { try ConstructionEngine(catalog: lib.buildCatalog).apply(c, to: &game.world) }
        let roofs = WeatherView.roofs(world: game.world, propertyID: game.activePropertyID)
        let top = game.world.grid.y(ofFloor: 9)
        #expect(roofs.contains { $0.minY == top })                                      // main roof
        #expect(roofs.count >= 2)                                                       // plus setbacks
        #expect(roofs.allSatisfy { abs($0.height - 0.35) < 1e-9 })
        let fp = b.footprint, grid = game.world.grid
        let street = WeatherView.pavement(world: game.world, propertyID: game.activePropertyID, visible: Rect(minX: -200, minY: -10, maxX: 300, maxY: 50))
        #expect(street.count == 2)
        #expect(street.allSatisfy { $0.upperBound <= grid.x(ofColumn: fp.start) || $0.lowerBound >= grid.x(ofColumn: fp.end) })
    }
}
