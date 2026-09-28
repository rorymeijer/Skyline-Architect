import Foundation
import SkylineCore

/// Zoom limits and the world region the camera may look at.
public struct CameraLimits: Hashable, Sendable {
    /// Minimum and maximum zoom in screen points per world meter.
    public var minZoom: Double
    public var maxZoom: Double
    /// The camera center is clamped so the view stays within this region whenever the
    /// view is smaller than the region (see `Camera2D.clampCenter`).
    public var bounds: Rect
    /// Screen points along the bottom edge covered by interface (the build bar). The view
    /// may extend this far below `bounds`, so the lowest ground can always be panned into
    /// sight above it, at any zoom.
    public var bottomInset: Double

    public init(minZoom: Double, maxZoom: Double, bounds: Rect, bottomInset: Double = 0) {
        precondition(minZoom > 0 && maxZoom >= minZoom && bottomInset >= 0)
        self.minZoom = minZoom
        self.maxZoom = maxZoom
        self.bounds = bounds
        self.bottomInset = bottomInset
    }

    /// Defaults: from ~0.35 pt/m (a 900 pt high window shows 2.5 km — a very tall tower)
    /// down to 96 pt/m (a person is ~160 pt tall).
    public static func standard(bounds: Rect, bottomInset: Double = 0) -> CameraLimits {
        CameraLimits(minZoom: 0.35, maxZoom: 96, bounds: bounds, bottomInset: bottomInset)
    }
}

/// Orthographic 2D camera. Screen space: points, origin bottom-left, y up (SpriteKit
/// convention). World space: meters, y up, grade at y = 0.
public struct Camera2D: Hashable, Sendable {
    public private(set) var center: Vec2
    public private(set) var zoom: Double
    public private(set) var viewportSize: Vec2
    public private(set) var limits: CameraLimits

    public init(center: Vec2, zoom: Double, viewportSize: Vec2, limits: CameraLimits) {
        self.center = center
        self.zoom = zoom
        self.viewportSize = viewportSize
        self.limits = limits
        self.zoom = clampZoom(zoom)
        clampCenter()
    }

    // MARK: Conversions

    public func worldToScreen(_ p: Vec2) -> Vec2 { (p - center) * zoom + viewportSize / 2 }
    public func screenToWorld(_ s: Vec2) -> Vec2 { (s - viewportSize / 2) / zoom + center }

    /// World rect currently visible.
    public var visibleRect: Rect { Rect(center: center, size: viewportSize / zoom) }

    // MARK: Mutation

    /// Sets zoom while keeping the world point under `anchor` (screen) fixed on screen.
    public mutating func setZoom(_ newZoom: Double, anchoredAt anchor: Vec2) {
        let worldAnchor = screenToWorld(anchor)
        zoom = clampZoom(newZoom)
        center = worldAnchor - (anchor - viewportSize / 2) / zoom
        clampCenter()
    }

    /// Moves the *content* by a screen delta (drag right ⇒ content moves right).
    public mutating func pan(byScreenDelta delta: Vec2) {
        center -= delta / zoom
        clampCenter()
    }

    public mutating func setCenter(_ c: Vec2) {
        center = c
        clampCenter()
    }

    public mutating func setViewportSize(_ size: Vec2) {
        viewportSize = Vec2(max(1, size.x), max(1, size.y))
        clampCenter()
    }

    public mutating func setLimits(_ l: CameraLimits) {
        limits = l
        zoom = clampZoom(zoom)
        clampCenter()
    }

    /// Centers on `rect` and zooms so it fits with `padding` (fraction of viewport).
    public mutating func frame(_ rect: Rect, padding: Double = 0.05) {
        let usable = viewportSize * (1 - 2 * padding)
        zoom = clampZoom(min(usable.x / max(rect.width, 1e-6), usable.y / max(rect.height, 1e-6)))
        center = rect.center
        clampCenter()
    }

    public func clampZoom(_ z: Double) -> Double { min(max(z, limits.minZoom), limits.maxZoom) }

    /// Keeps the view inside `limits.bounds` on each axis where the view is smaller
    /// than the bounds; otherwise centers the bounds on that axis. Vertically the bounds
    /// reach `bottomInset` points further down (the part hidden behind the interface).
    mutating func clampCenter() {
        let half = viewportSize / (2 * zoom)
        let b = limits.bounds
        center.x = Self.clampAxis(center.x, half: half.x, lo: b.minX, hi: b.maxX)
        center.y = Self.clampAxis(center.y, half: half.y, lo: b.minY - limits.bottomInset / zoom, hi: b.maxY)
    }

    static func clampAxis(_ c: Double, half: Double, lo: Double, hi: Double) -> Double {
        if hi - lo <= 2 * half { return (lo + hi) / 2 }
        return min(max(c, lo + half), hi - half)
    }
}
