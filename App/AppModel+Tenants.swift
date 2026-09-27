import Foundation
import SkylineCore
import SkylinePresentation
import SkylineSimulation

extension AppModel {
    // MARK: Selection and leasing (Phase 8)

    /// Selects the room under a grid cell of the active property (nil cell or no room clears).
    func selectRoom(at cell: GridCell?) {
        guard let cell, let world, let property = activePropertyID,
              let room = world.buildings(on: property).lazy.compactMap({ world.room(in: $0.id, column: cell.column, floor: cell.floor) }).first else {
            selectedRoom = nil
            unitReport = nil
            scene?.selectionRect = nil
            return
        }
        selectedRoom = room.id
        scene?.selectionRect = world.grid.rect(columns: room.columns, floors: room.floors)
        refreshLeasing()
    }

    func refreshLeasing() {
        guard let world, let property = activePropertyID, let simulation else { return }
        if let id = selectedRoom {
            if let room = world.rooms[id] {
                unitReport = UnitReport.make(room: room, world: world, engine: simulation)
            } else {
                selectRoom(at: nil)
            }
        }
        leasing = LeasingSummary.make(world: world, engine: simulation, buildings: world.buildings(on: property).map(\.id))
    }

    /// Room label text: the tenant's name, or "vacant" for rentable units without a tenant.
    func roomLabelText(_ room: Room, _ spec: RoomSpec) -> String? {
        guard let world, spec.rentPerModule != nil else { return nil }
        return world.tenants.values.first { $0.room == room.id }?.name ?? "\(spec.name) · vacant"
    }

    #if DEBUG
    /// Developer tool: every vacant unit is rented immediately (default tenant types).
    func leaseAllVacant() {
        guard var w = world, let library else { return }
        Leasing.fillAll(&w, catalog: library.buildCatalog, rules: library.simulationRules)
        world = w
        hasUnsavedChanges = true
        refreshSimulationSummary()
    }
    #endif
}
