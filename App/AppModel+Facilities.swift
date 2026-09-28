import Foundation
import SkylineCore
import SkylineSimulation

extension AppModel {
    // MARK: Facilities (Phase 10)

    func refreshFacilities() {
        guard let world, let simulation else { return }
        let building = activePropertyID.flatMap { world.buildings(on: $0).first?.id }
        facilities = FacilitiesSummary.make(world: world, engine: simulation, building: building,
                                            service: building.flatMap { utilityServices[$0] })
        var served: [RoomID: Double] = [:]
        var watts = 0.0
        for b in activePropertyID.map({ world.buildings(on: $0) }) ?? [] {
            let service = utilityServices[b.id]
                ?? Utilities.allocate(building: b.id, world: world, catalog: simulation.catalog, rules: simulation.rules)
            for (room, utilities) in service.served { if let e = utilities["electricity"] { served[room] = e } }
            watts += Energy.lightingWatts(of: b.id, world: world, engine: simulation, service: service)
        }
        electricityServed = served
        lightingKW = watts / 1000
        lightingKWhToday = building.flatMap { world.buildings[$0]?.lightingKWh } ?? 0
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
        // Per frame while shown: reuse the 4 Hz allocation instead of allocating every frame.
        return ServicesOverlay.marks(world: world, engine: simulation, buildings: world.buildings(on: property).map(\.id),
                                     services: utilityServices)
    }
}
