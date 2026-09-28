import Foundation
import SkylineCore
import SkylinePresentation
import SkylineSimulation

extension AppModel {
    // MARK: Incidents (Phase 14)

    /// Refreshes fires and the log. A fire in progress keeps an alert up; any other new
    /// incident raises one until dismissed.
    func refreshIncidents() {
        guard let world else { return }
        let summary = IncidentSummary.make(world: world)
        if let world = self.world, let simulation, let property = activePropertyID {
            sprinklerRooms = Set(world.buildings(on: property).flatMap {
                FireSafety.protectedRooms(in: $0.id, world: world, catalog: simulation.catalog, failureBelow: simulation.rules.facilities?.failureBelow ?? 0)
            })
        }
        if let fire = summary.fires.first, fire.incident == dismissedFireID {
            // dismissed by the player: stay quiet until this fire is over
        } else if let fire = summary.fires.first {
            incidentNotice = "🔥 \(fire.detail) — \(fire.burningRooms) room\(fire.burningRooms == 1 ? "" : "s") burning, "
                + (fire.brigadeInMinutes > 0 ? "fire brigade in \(fire.brigadeInMinutes) min" : "fire brigade on site") + ", building evacuated"
        } else if let seen = seenIncidentID, summary.latestID > seen, let newest = summary.recent.first {
            incidentNotice = newest.kind == "fire" ? "Fire out: \(newest.detail)" : "⚠︎ \(newest.detail)"
        } else if !incidents.fires.isEmpty {
            incidentNotice = summary.recent.first.map { "Fire out: \($0.detail)" }
        }
        seenIncidentID = summary.latestID
        incidents = summary
    }

    func dismissIncidentNotice() {
        dismissedFireID = incidents.fires.first?.incident
        incidentNotice = nil
    }

    /// Moves the camera to the first burning room (or the newest incident's room).
    func showIncident() {
        guard let world, let scene else { return }
        let room = incidents.fires.first?.room
            ?? world.incidents.log.last?.rooms.first
        guard let id = room, let r = world.rooms[id] else { return }
        let rect = world.grid.rect(columns: r.columns, floors: r.floors)
        scene.withController { $0.jump(center: rect.center, zoom: 22) }
    }

    #if DEBUG
    /// Developer tool: sets the lowest office on fire.
    func igniteFirstOffice() {
        guard let world, let property = activePropertyID else { return }
        let offices = world.buildings(on: property).flatMap { world.rooms(in: $0.id) }.filter { $0.definitionID == "office-small" }
        if let office = offices.min(by: { ($0.floors.lowest, $0.id) < ($1.floors.lowest, $1.id) }) { igniteForTesting(office.id) }
    }

    /// Developer tool: sets a room on fire (Build ▸ Developer menu, captures).
    @discardableResult
    func igniteForTesting(_ room: RoomID) -> Bool {
        guard var w = world, let simulation else { return false }
        let ok = simulation.ignite(room, at: w.clock.tick, world: &w)
        world = w
        refreshSimulationSummary()
        return ok
    }
    #endif
}
