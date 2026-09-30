import Foundation
import SkylineCore
import SkylinePresentation

extension AppModel {
    // MARK: Held placement on touch (0.30)

    /// Builds the held placement (the Place button).
    func confirmHeldPlacement() {
        scene?.confirmHeldPlacement()
    }

    func cancelHeldPlacement() {
        scene?.cancelPlacement()
    }

    /// One module longer (+1) or shorter (−1): wider for rooms and floors, taller for shafts.
    /// Every press changes the ghost, also when a room was held at its minimum width (0.30.1).
    func nudgeHeldPlacement(by step: Int) {
        guard let scene, let tool = activeTool, let world, let property = activePropertyID, let engine,
              let held = scene.heldCells else { return }
        scene.holdPlacement(end: PlacementPlanner.nudgedVisibly(held.end, anchor: held.anchor, tool: tool, world: world,
                                                                propertyID: property, engine: engine, by: step))
    }

    /// "Wider" or "Taller" for the ± buttons of the active tool.
    var heldGrowsVertically: Bool {
        if case .room(let id)? = activeTool { return catalog?.spec(id)?.kind == .shaft }
        return false
    }
}
