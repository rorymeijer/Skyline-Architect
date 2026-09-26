import Foundation
import SkylineCore

/// Tunables for camera feel. All rates are per second; behaviour is frame-rate independent.
public struct CameraFeel: Hashable, Sendable {
    /// How quickly animated zoom converges on its target (higher = snappier).
    public var zoomSharpness: Double = 16
    /// Exponential decay rate of pan inertia.
    public var inertiaFriction: Double = 4.5
    /// Inertia stops below this screen speed (points/s).
    public var inertiaStopSpeed: Double = 8
    /// Keyboard pan speed in screen points/s (zoom-independent feel).
    public var keyboardPanSpeed: Double = 900
    /// Keyboard zoom factor per second while a zoom key is held.
    public var keyboardZoomRate: Double = 3
    /// Zoom factor per mouse-wheel line.
    public var wheelZoomStep: Double = 1.18
    /// Only the most recent drag movement within this window sets release velocity.
    public var velocitySampleWindow: Double = 0.1

    public init() {}
}

/// Turns input intents into camera motion: drag panning with inertia, smooth zoom toward
/// an anchor, keyboard panning/zooming. Pure value type — platform views translate their
/// events into these calls and call `update(dt:)` once per frame.
public struct CameraController: Sendable {
    public private(set) var camera: Camera2D
    public var feel = CameraFeel()

    /// Held-key directions, each component in -1…1 (set by the platform view).
    public var keyboardPan = Vec2.zero
    /// Held-key zoom direction, -1…1 (positive zooms in).
    public var keyboardZoom = 0.0

    private var targetZoom: Double
    private var zoomAnchor: Vec2
    private var velocity = Vec2.zero
    private var isDragging = false
    private var dragSamples: [(time: Double, delta: Vec2)] = []

    public init(camera: Camera2D) {
        self.camera = camera
        targetZoom = camera.zoom
        zoomAnchor = camera.viewportSize / 2
    }

    /// True while inertia or animated zoom is still moving the camera.
    public var isAnimating: Bool {
        velocity.length > 0 || abs(targetZoom - camera.zoom) > 0 || keyboardPan != .zero || keyboardZoom != 0
    }

    // MARK: Direct manipulation

    public mutating func beginDrag(at time: Double) {
        isDragging = true
        velocity = .zero
        dragSamples.removeAll(keepingCapacity: true)
        targetZoom = camera.zoom
    }

    public mutating func drag(by screenDelta: Vec2, at time: Double) {
        camera.pan(byScreenDelta: screenDelta)
        dragSamples.append((time, screenDelta))
        dragSamples.removeAll { time - $0.time > feel.velocitySampleWindow }
    }

    /// Ends a drag; recent movement becomes inertia.
    public mutating func endDrag(at time: Double) {
        isDragging = false
        let recent = dragSamples.filter { time - $0.time <= feel.velocitySampleWindow }
        dragSamples.removeAll(keepingCapacity: true)
        guard let first = recent.first, recent.count >= 2 else { velocity = .zero; return }
        let span = max(time - first.time, 1.0 / 120.0)
        let total = recent.dropFirst().reduce(Vec2.zero) { $0 + $1.delta }
        velocity = total / span
        if velocity.length < feel.inertiaStopSpeed { velocity = .zero }
    }

    /// Immediate pan (trackpad scrolling — the OS already supplies momentum events).
    public mutating func scrollPan(by screenDelta: Vec2) {
        velocity = .zero
        camera.pan(byScreenDelta: screenDelta)
    }

    /// Multiplies zoom by `factor` keeping `anchor` (screen point) fixed.
    /// `animated` zooms smoothly (mouse wheel, keys); otherwise immediate (pinch).
    public mutating func zoom(by factor: Double, at anchor: Vec2, animated: Bool) {
        if animated {
            targetZoom = camera.clampZoom(targetZoom * factor)
            zoomAnchor = anchor
        } else {
            camera.setZoom(camera.zoom * factor, anchoredAt: anchor)
            targetZoom = camera.zoom
        }
    }

    public mutating func zoomByWheel(lines: Double, at anchor: Vec2) {
        zoom(by: pow(feel.wheelZoomStep, lines), at: anchor, animated: true)
    }

    /// Instantly places the camera (presets, reset view). Cancels all motion.
    public mutating func jump(center: Vec2, zoom: Double) {
        stopMotion()
        camera.setZoom(zoom, anchoredAt: camera.viewportSize / 2)
        camera.setCenter(center)
        targetZoom = camera.zoom
    }

    public mutating func frame(_ rect: Rect, padding: Double = 0.05) {
        stopMotion()
        camera.frame(rect, padding: padding)
        targetZoom = camera.zoom
    }

    public mutating func stopMotion() {
        velocity = .zero
        targetZoom = camera.zoom
        dragSamples.removeAll()
    }

    public mutating func setViewportSize(_ size: Vec2) {
        // Keep the world point at the view center fixed while resizing.
        let c = camera.center
        camera.setViewportSize(size)
        camera.setCenter(c)
        zoomAnchor = camera.viewportSize / 2
    }

    public mutating func setLimits(_ limits: CameraLimits) {
        camera.setLimits(limits)
        targetZoom = camera.clampZoom(targetZoom)
    }

    // MARK: Per-frame

    /// Advances animations by `dt` seconds. Returns true if the camera changed.
    @discardableResult
    public mutating func update(dt: Double) -> Bool {
        guard dt > 0 else { return false }
        let before = camera

        if keyboardPan != .zero {
            // Keys move the view, so content moves opposite to the key direction.
            camera.pan(byScreenDelta: -keyboardPan * (feel.keyboardPanSpeed * dt))
        }
        if keyboardZoom != 0 {
            targetZoom = camera.clampZoom(targetZoom * pow(feel.keyboardZoomRate, keyboardZoom * dt))
            zoomAnchor = camera.viewportSize / 2
        }

        if !isDragging, velocity != .zero {
            camera.pan(byScreenDelta: velocity * dt)
            velocity = velocity * exp(-feel.inertiaFriction * dt)
            if velocity.length < feel.inertiaStopSpeed { velocity = .zero }
        }

        if targetZoom != camera.zoom {
            let ratio = targetZoom / camera.zoom
            if abs(ratio - 1) < 1e-4 {
                camera.setZoom(targetZoom, anchoredAt: zoomAnchor)
            } else {
                // Interpolate in log space so zooming feels uniform at every scale.
                let t = 1 - exp(-feel.zoomSharpness * dt)
                camera.setZoom(camera.zoom * pow(ratio, t), anchoredAt: zoomAnchor)
            }
            // Clamping may prevent reaching the target (limits); converge anyway.
            if camera.zoom == before.zoom { targetZoom = camera.zoom }
        }
        return camera != before
    }
}
