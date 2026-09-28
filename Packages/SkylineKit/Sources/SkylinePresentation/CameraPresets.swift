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
    /// The whole building (all storeys and the foundation).
    case building

    /// `bottomInset`: screen points along the bottom covered by interface. The preset is
    /// framed in the part of the view above it (see `CameraLimits.bottomInset`).
    public func placement(for c: SiteComposition, viewport full: Vec2, bottomInset: Double = 0) -> (center: Vec2, zoom: Double) {
        let inset = self == .detail ? 0 : min(max(bottomInset, 0), full.y / 2)
        let viewport = Vec2(full.x, full.y - inset)
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
        case .building:
            let f = c.foundationRect ?? c.frontageRect
            let whole = c.superstructureRect.map { f.union($0.insetBy(dx: -2, dy: -3)) } ?? f
            cam.frame(whole, padding: 0.04)
        case .skyline:
            cam.setZoom(0.45, anchoredAt: viewport / 2)
            cam.setCenter(Vec2(c.siteRect.center.x, viewport.y / 0.45 / 2 - 60))
        }
        // Framed above the interface: the full view reaches that much further down.
        return (Vec2(cam.center.x, cam.center.y - inset / (2 * cam.zoom)), cam.zoom)
    }
}
