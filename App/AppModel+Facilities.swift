import Foundation
import SkylineCore
import SkylineSimulation

extension AppModel {
    // MARK: Facilities (Phase 10)

    func refreshFacilities() {
        guard let world, let simulation else { return }
        let building = activePropertyID.flatMap { world.buildings(on: $0).first?.id }
        facilities = FacilitiesSummary.make(world: world, engine: simulation, building: building)
    }

    /// Hires (+1) or dismisses (−1) a janitor or technician for the active building.
    func changeStaff(_ role: PersonRole, by delta: Int) {
        guard var w = world, let simulation, let property = activePropertyID, let building = w.buildings(on: property).first else { return }
        if delta > 0 {
            FacilitiesManagement.hire(role, building: building.id, world: &w, rules: simulation.rules)
        } else {
            FacilitiesManagement.dismiss(role, world: &w)
        }
        world = w
        hasUnsavedChanges = true
        refreshSimulationSummary()
    }

    /// Room problems for the services overlay, or nil when it is hidden.
    func serviceMarks() -> [ServiceMark]? {
        guard showServices, let world, let simulation, let property = activePropertyID else { return nil }
        return ServicesOverlay.marks(world: world, engine: simulation, buildings: world.buildings(on: property).map(\.id))
    }
}
