import Foundation
import SkylineCore
import SkylinePresentation
import SkylineSimulation

extension AppModel {
    // MARK: Weather (Phase 13)

    func refreshWeather() {
        guard let world, let simulation else { return }
        weather = WeatherSummary.make(world: world, rules: simulation.rules)
    }

    /// The weather's look at a (fractional) tick, for the renderer.
    func weatherLook(at time: Double) -> WeatherLook {
        WeatherView.look(state: world?.weather, rules: simulation?.rules.weather, time: time)
    }

    /// Lighting and weather providers of a new scene (Phases 12, 13).
    func installEnvironment(on scene: WorldScene) {
        scene.lightingProvider = { [weak self] visible, zoom in
            guard let self, let world = self.world, let property = self.activePropertyID, let catalog = self.catalog else { return (.day, 0, 0, []) }
            let t = Double(world.clock.tick) + self.host.fraction
            let look = self.weatherLook(at: t)
            let darkness = WeatherView.darkness(daylight: DayNight.daylight(atTick: t), look: look)
            return (WeatherView.grade(DayNight.grade(atTick: t), look: look), darkness,
                    (1 - DayNight.daylight(atTick: t)) * (1 - 0.6 * look.fog),
                    DayNight.litRooms(world: world, propertyID: property, catalog: catalog, time: t, visible: visible, zoom: zoom,
                                      power: self.electricityServed, darkness: darkness))
        }
        scene.fireProvider = { [weak self] in
            guard let self, let world = self.world, let property = self.activePropertyID else { return ([], [], []) }
            let t = Double(world.clock.tick) + self.host.fraction
            return (FireView.flames(world: world, propertyID: property, time: t, protected: self.sprinklerRooms),
                    FireView.engines(world: world, propertyID: property, time: t), FireView.scorched(world: world, propertyID: property))
        }
        scene.weatherProvider = { [weak self] visible in
            guard let self, let world = self.world, let property = self.activePropertyID else { return (.clear, [], []) }
            let look = self.weatherLook(at: Double(world.clock.tick) + self.host.fraction)
            // Roofs only matter under snow (the layer hides them otherwise).
            return (look, look.snowCover > 0.01 ? WeatherView.roofs(world: world, propertyID: property) : [],
                    WeatherView.pavement(world: world, propertyID: property, visible: visible))
        }
    }
}
