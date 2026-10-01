import Foundation
import SkylineCore
import SkylinePresentation
import SkylineSimulation

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

    // MARK: The picked tool (0.30.3)

    /// Name, size and price of the active tool, for the bar above the palette.
    var toolSummary: ToolSummary? {
        guard let tool = activeTool, let world, let property = activePropertyID, let catalog else { return nil }
        var detail: String?
        if case .room(let id) = tool { detail = simulation?.rules.elevator(for: id)?.name }
        return ToolSummary.make(tool: tool, world: world, propertyID: property, catalog: catalog, detail: detail)
    }

    /// The palette's icon for the active tool.
    var toolSymbol: String {
        switch activeTool {
        case .room(let id)?: catalog?.spec(id).map(BuildPalette.symbol(for:)) ?? "square.dashed"
        case .demolish?: "hammer"
        default: "square.stack.3d.up"
        }
    }

    /// Why the active room type cannot be placed yet, if so.
    var activeToolLock: String? {
        if case .room(let id)? = activeTool { return lockReason(of: id) }
        return nil
    }
}
