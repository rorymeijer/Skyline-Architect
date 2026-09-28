import Foundation
import SkylineContent
import SkylineCore

extension AppModel {
    // MARK: Estate (Phase 15)

    func refreshEstate() {
        guard let world, let library else { return }
        estate = EstateSummary.make(world: world, library: library)
    }

    func toggleEstatePanel() {
        showEstatePanel.toggle()
        if showEstatePanel { refreshEstate() }
    }

    /// Looks at another property: a new scene for it; the simulation keeps running everywhere.
    func switchProperty(_ id: PropertyID) {
        guard let world, id != activePropertyID, world.properties.contains(id) else { return }
        let unsaved = hasUnsavedChanges
        install(world: world, activePropertyID: id, keepCamera: false)
        hasUnsavedChanges = unsaved
    }

    /// Buys a plot and switches to it.
    func buyPlot(_ plotID: String) {
        guard var w = world, let library else { return }
        do {
            let property = try Estate.buy(plotID, world: &w, library: library)
            world = w
            hasUnsavedChanges = true
            install(world: w, activePropertyID: property, keepCamera: false)
            hasUnsavedChanges = true
        } catch {
            alert = AppAlert(title: "Cannot buy this plot", message: "\(error)")
        }
    }
}
