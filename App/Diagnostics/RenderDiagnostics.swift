import Foundation
import SkylineCore
import SkylinePresentation

/// Snapshot of renderer performance and view state, published to the HUD at 4 Hz.
struct RenderDiagnostics: Equatable, Codable {
    var fps = 0.0
    var frameTimeMs = 0.0
    var sceneUpdateMs = 0.0
    var nodeCount = 0
    var tileLevel = 0
    var tilesVisible = 0
    var tilesCached = 0
    var tilesPending = 0
    var tilesRasterized = 0
    var tileRasterMs = 0.0
    var agentsRendered = 0
    var memoryMB = 0.0
    var zoom = 0.0
    var detailLevel = "—"
    var centerX = 0.0
    var centerY = 0.0
    var viewportWidth = 0.0
    var viewportHeight = 0.0
    var backingScale = 1.0
    var cursorCell: String?
    var cursorWorld: String?
}
