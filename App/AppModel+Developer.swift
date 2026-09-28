#if DEBUG
import Foundation
import SkylineContent
import SkylineSimulation

extension AppModel {
    /// Developer tool (Phase 19): replaces the game with the generated stress tower — every
    /// unit let — to profile rendering and simulation at scale. Never part of gameplay.
    func loadStressTower(zones: Int) {
        guard let library else { return }
        do {
            let width = StressTower.minimumWidth(zones: zones) + 4
            var (w, property) = try StressTower.world(zones: zones, width: width, library: library)
            PopulationSync.sync(&w, catalog: library.buildCatalog, rules: library.simulationRules)
            Leasing.fillAll(&w, catalog: library.buildCatalog, rules: library.simulationRules)
            install(world: w, activePropertyID: property, keepCamera: false)
        } catch {
            alert = AppAlert(title: "Could not build the stress tower", message: "\(error)")
        }
    }
}
#endif
