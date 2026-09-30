import Foundation
import SkylineCore
import SkylinePresentation
import SkylineSimulation

/// One height control of a selected shaft: the command it would perform (nil = not
/// possible now) and its price or the reason why not.
struct ConstructionOption: Identifiable, Equatable {
    let id: String
    let title: String
    let symbol: String
    let command: BuildCommand?
    let detail: String
}

extension AppModel {
    // MARK: Shaft height (0.20.2)

    /// Extend or shorten the selected shaft by one floor at the top or the bottom. The same
    /// `resizeRoom` command as dragging a shaft's end with its tool; validated here, not in
    /// the view.
    func refreshShaftOptions() {
        guard let world, let engine, let id = selectedRoom, let room = world.rooms[id],
              engine.catalog.spec(room.definitionID)?.kind == .shaft else {
            if !shaftOptions.isEmpty { shaftOptions = [] }
            if !elevatorStops.isEmpty { elevatorStops = [] }
            return
        }
        refreshElevatorStops(room, world: world)
        let f = room.floors
        let steps: [(String, String, String, FloorSpan)] = [
            ("up", "Extend Up", "arrow.up.to.line", FloorSpan(lowest: f.lowest, highest: f.highest + 1)),
            ("top", "Shorten Top", "arrow.down.to.line", FloorSpan(lowest: f.lowest, highest: f.highest - 1)),
            ("down", "Extend Down", "arrow.down.to.line.compact", FloorSpan(lowest: f.lowest - 1, highest: f.highest)),
            ("bottom", "Shorten Bottom", "arrow.up.to.line.compact", FloorSpan(lowest: f.lowest + 1, highest: f.highest)),
        ]
        let options = steps.map { key, title, symbol, floors -> ConstructionOption in
            guard floors.lowest <= floors.highest else {
                return ConstructionOption(id: key, title: title, symbol: symbol, command: nil, detail: "Too short already")
            }
            // Extending past the existing floors builds the missing plates too (0.30.1).
            let (command, added) = engine.addingFloors(for: .resizeRoom(id, floors: floors), in: world)
            switch engine.validate(command, in: world) {
            case .success(let plan):
                var price = plan.cost < 0 ? "refund \(Money.format(-plan.cost))" : Money.format(plan.cost)
                if added > 0 { price += added == 1 ? " · +1 new floor" : " · +\(added) new floors" }
                guard plan.cost <= world.ledger.cash else {
                    return ConstructionOption(id: key, title: title, symbol: symbol, command: nil, detail: "Not enough money (\(price))")
                }
                return ConstructionOption(id: key, title: title, symbol: symbol, command: command, detail: price)
            case .failure(let error):
                return ConstructionOption(id: key, title: title, symbol: symbol, command: nil, detail: "\(error)")
            }
        }
        if options != shaftOptions { shaftOptions = options }
    }
}

/// One floor of a selected elevator (0.30): whether the car stops there, and whether that
/// may change (at least two floors stay on).
struct ElevatorStopToggle: Identifiable, Equatable {
    let floor: Int
    let label: String
    let served: Bool
    let canToggle: Bool
    var id: Int { floor }
}

extension AppModel {
    // MARK: Elevator stops (0.30)

    func refreshElevatorStops(_ room: Room, world: GameWorld) {
        guard let rules = simulation?.rules, let spec = rules.elevator(for: room.definitionID), world.elevators.contains(room.id) else {
            if !elevatorStops.isEmpty { elevatorStops = [] }
            return
        }
        let served = Set(ElevatorStops.served(room, world: world, rules: rules))
        let toggles = spec.stopFloors(of: room.floors).reversed().map { floor in
            ElevatorStopToggle(floor: floor, label: FloorLabel.label(for: floor), served: served.contains(floor),
                               canToggle: !served.contains(floor) || served.count > 2)
        }
        if toggles != elevatorStops { elevatorStops = toggles }
    }

    /// Switches a floor of the selected elevator on or off (a player setting like the
    /// dispatch strategy, not a construction step).
    func setStop(_ floor: Int, served: Bool) {
        guard var w = world, let simulation, let id = selectedRoom else { return }
        do {
            try ElevatorStops.set(floor, served: served, shaft: id, world: &w, rules: simulation.rules)
        } catch {
            alert = AppAlert(title: "Cannot change this stop", message: "\(error)")
            return
        }
        world = w
        hasUnsavedChanges = true
        refreshShaftOptions()
        refreshSimulationSummary()
        scene?.invalidateOverlays()                        // the floor numbers in the shaft
    }
}
