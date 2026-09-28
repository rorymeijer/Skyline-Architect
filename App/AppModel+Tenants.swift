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
            shaftOptions = []
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
                // The selection follows a room that changed size (a resized shaft, a room that made way).
                let rect = world.grid.rect(columns: room.columns, floors: room.floors)
                if scene?.selectionRect != rect { scene?.selectionRect = rect }
            } else {
                selectRoom(at: nil)
            }
        }
        refreshShaftOptions()
        leasing = LeasingSummary.make(world: world, engine: simulation, buildings: world.buildings(on: property).map(\.id))
    }

    /// Room label text: the tenant's name ("· owner" for a flat they bought), or what an
    /// empty unit is: "Vacant", "For sale" or "For resale" (a sold flat between owners).
    func roomLabelText(_ room: Room, _ spec: RoomSpec) -> String? {
        guard let world, spec.rentPerModule != nil else { return nil }
        if let tenant = world.tenants.values.first(where: { $0.room == room.id }) {
            return tenant.isOwner ? tenant.name + " · owner" : tenant.name
        }
        switch room.tenure ?? .rent {
        case .rent: return "Vacant"
        case .forSale: return "For sale"
        case .owned: return "For resale"
        }
    }

    /// Offers the selected vacant flat for sale, or for rent again (0.20.3).
    func offerSelectedUnit(forSale: Bool) {
        guard var w = world, let id = selectedRoom, let simulation, let catalog else { return }
        do {
            try Leasing.setTenure(forSale ? .forSale : .rent, room: id, world: &w, rules: simulation.rules, catalog: catalog)
            world = w
            hasUnsavedChanges = true
            refreshLeasing()
        } catch {
            alert = AppAlert(title: forSale ? "Cannot offer this unit for sale" : "Cannot rent this unit out", message: "\(error)")
        }
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
