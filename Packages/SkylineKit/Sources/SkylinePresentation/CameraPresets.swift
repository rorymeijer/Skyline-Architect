import Foundation
import SkylineCore

/// Named, deterministic camera placements used for "reset view", keyboard shortcuts and
/// screenshot capture. Expressed as center + zoom so any viewport size can use them.
public enum CameraPreset: String, CaseIterable, Sendable {
    /// Whole site with context: plot, neighbours, ground section.
    case overview
    /// The foundation filling the view.
    case foundation
    /// Close-up of a retaining wall, raft and pile heads (interior LOD).
    case detail
    /// Far zoom-out showing how high the (unlimited) grid reaches.
    case skyline

    public func placement(for c: SiteComposition, viewport: Vec2) -> (center: Vec2, zoom: Double) {
        var cam = Camera2D(center: .zero, zoom: 1, viewportSize: viewport,
                           limits: .standard(bounds: c.cameraBounds))
        switch self {
        case .overview:
            let r = Rect(minX: c.siteRect.minX, minY: -32, maxX: c.siteRect.maxX, maxY: 58)
            cam.frame(r, padding: 0.02)
        case .foundation:
            let f = c.foundationRect ?? c.frontageRect
            cam.frame(f.insetBy(dx: -4, dy: -3), padding: 0.04)
        case .detail:
            let f = c.foundationRect ?? c.frontageRect
            let x = f.minX + 1  // the left retaining wall
            cam.setZoom(64, anchoredAt: viewport / 2)
            cam.setCenter(Vec2(x + 3.2, -4.2))
        case .skyline:
            cam.setZoom(0.45, anchoredAt: viewport / 2)
            cam.setCenter(Vec2(c.siteRect.center.x, viewport.y / 0.45 / 2 - 60))
        }
        return (cam.center, cam.zoom)
    }
}
