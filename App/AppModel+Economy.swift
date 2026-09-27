import Foundation
import SkylineCore
import SkylinePersistence
import SkylineSimulation

extension AppModel {
    // MARK: Money (Phase 9)

    func refreshEconomy() {
        guard let world, let simulation else { return }
        let building = activePropertyID.flatMap { world.buildings(on: $0).first?.id }
        economy = EconomySummary.make(world: world, rules: simulation.rules, building: building)
        if world.ledger.bankrupt && speed != .paused { setSpeed(.paused) }
    }

    func borrow() { changeLedger { w, rules in Economy.borrow(&w, rules: rules) } }
    func repay() { changeLedger { w, rules in Economy.repay(&w, rules: rules) } }

    /// Changes the active building's rent level by `delta` (player setting, no undo).
    func adjustRentLevel(by delta: Double) {
        guard var w = world, let property = activePropertyID, let building = w.buildings(on: property).first else { return }
        Economy.setRentLevel(((building.rentLevel + delta) * 10).rounded() / 10, building: building.id, in: &w)
        world = w
        hasUnsavedChanges = true
        refreshSimulationSummary()
    }

    private func changeLedger(_ body: (inout GameWorld, EconomyRules) -> Bool) {
        guard var w = world, let rules = simulation?.rules.economy, body(&w, rules) else { return }
        world = w
        hasUnsavedChanges = true
        refreshSimulationSummary()
    }

    // MARK: Main menu

    /// The newest save (quicksave, named or autosave), if any.
    var latestSave: SaveSlotInfo? { saveStore.list().first { $0.metadata != nil } }

    func continueLatest() {
        guard let slot = latestSave?.slot, load(slot: slot) else { return }
        showMainMenu = false
        setSpeed(.normal)
    }

    func startFromMenu() {
        newGame()
        showMainMenu = false
        setSpeed(.normal)
    }
}
