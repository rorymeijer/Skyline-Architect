#if os(macOS)
import AppKit
import SpriteKit
import SkylineCore
import SkylinePresentation

/// macOS game view: translates trackpad, mouse and keyboard input into camera intents.
///
/// - Trackpad: two-finger scroll pans (with system momentum), pinch zooms at the cursor,
///   ⌘/⌥ + scroll zooms.
/// - Mouse: wheel zooms smoothly toward the cursor; left/right/middle drag pans with inertia.
/// - Keyboard: WASD / arrows pan, Q/E or −/= zoom, G toggles the grid, F floor tool,
///   X demolish tool, Esc cancels the tool, Space pauses, 1–6 set 1×/2×/4×/10×/30×/60×.
/// - With a construction tool active, left-drag places (right/middle drag still pans).
final class GameSKView: SKView {
    var onToggleGrid: (() -> Void)?
    /// Tool shortcuts: "floor", "demolish", "cancel".
    var onToolKey: ((String) -> Void)?
    private var isPlacing = false
    /// Where a left click started (window coordinates), to tell clicks from drags.
    private var clickStart: CGPoint?

    private var worldScene: WorldScene? { scene as? WorldScene }
    private var trackingArea: NSTrackingArea?
    private var heldKeys = Set<UInt16>()

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        window?.acceptsMouseMovedEvents = true
        updateBackingScale()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateBackingScale()
    }

    private func updateBackingScale() {
        worldScene?.backingScale = window?.backingScaleFactor ?? 2
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    private func scenePoint(_ event: NSEvent) -> CGPoint {
        let p = convert(event.locationInWindow, from: nil)
        guard let scene else { return p }
        return scene.convertPoint(fromView: p)
    }

    // MARK: Scroll & pinch

    override func scrollWheel(with event: NSEvent) {
        guard let worldScene else { return }
        let point = Vec2(scenePoint(event))
        if event.hasPreciseScrollingDeltas {
            if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.option) {
                let factor = exp(Double(event.scrollingDeltaY) * 0.01)
                worldScene.withController { $0.zoom(by: factor, at: point, animated: false) }
            } else {
                // Natural scrolling: content follows the fingers.
                let delta = Vec2(Double(event.scrollingDeltaX), -Double(event.scrollingDeltaY))
                worldScene.withController { $0.scrollPan(by: delta) }
            }
        } else {
            let lines = max(-6, min(6, Double(event.scrollingDeltaY)))
            guard lines != 0 else { return }
            worldScene.withController { $0.zoomByWheel(lines: lines, at: point) }
        }
        worldScene.hoverPoint = scenePoint(event)
    }

    override func magnify(with event: NSEvent) {
        let point = Vec2(scenePoint(event))
        let factor = max(0.2, 1 + Double(event.magnification))
        worldScene?.withController { $0.zoom(by: factor, at: point, animated: false) }
    }

    // MARK: Drag panning

    override func mouseDown(with event: NSEvent) {
        if let worldScene, worldScene.activeTool != nil {
            window?.makeFirstResponder(self)
            isPlacing = true
            worldScene.beginPlacement(at: scenePoint(event))
        } else {
            clickStart = event.locationInWindow
            beginDrag(event)
        }
    }
    override func rightMouseDown(with event: NSEvent) {
        if isPlacing { isPlacing = false; worldScene?.cancelPlacement() }
        beginDrag(event)
    }
    override func otherMouseDown(with event: NSEvent) { beginDrag(event) }
    override func mouseDragged(with event: NSEvent) {
        if isPlacing { worldScene?.updatePlacement(at: scenePoint(event)) } else { drag(event) }
    }
    override func rightMouseDragged(with event: NSEvent) { drag(event) }
    override func otherMouseDragged(with event: NSEvent) { drag(event) }
    override func mouseUp(with event: NSEvent) {
        if isPlacing {
            isPlacing = false
            worldScene?.endPlacement(at: scenePoint(event))
        } else {
            endDrag(event)
            // A click that did not move is a selection.
            if let start = clickStart, hypot(event.locationInWindow.x - start.x, event.locationInWindow.y - start.y) < 4 {
                worldScene?.select(at: scenePoint(event))
            }
            clickStart = nil
        }
    }
    override func rightMouseUp(with event: NSEvent) { endDrag(event) }
    override func otherMouseUp(with event: NSEvent) { endDrag(event) }

    private func beginDrag(_ event: NSEvent) {
        window?.makeFirstResponder(self)
        worldScene?.withController { $0.beginDrag(at: event.timestamp) }
    }

    private func drag(_ event: NSEvent) {
        // deltaY is positive when the mouse moves down the screen; world y points up.
        let delta = Vec2(Double(event.deltaX), -Double(event.deltaY))
        worldScene?.withController { $0.drag(by: delta, at: event.timestamp) }
        worldScene?.hoverPoint = scenePoint(event)
    }

    private func endDrag(_ event: NSEvent) {
        worldScene?.withController { $0.endDrag(at: event.timestamp) }
    }

    // MARK: Hover

    override func mouseMoved(with event: NSEvent) { worldScene?.hoverPoint = scenePoint(event) }
    override func mouseExited(with event: NSEvent) { worldScene?.hoverPoint = nil }

    // MARK: Keyboard

    private enum Key {
        static let a: UInt16 = 0, s: UInt16 = 1, d: UInt16 = 2, f: UInt16 = 3, g: UInt16 = 5, x: UInt16 = 7
        static let q: UInt16 = 12, w: UInt16 = 13, e: UInt16 = 14, escape: UInt16 = 53, space: UInt16 = 49
        static let digits: [UInt16: String] = [18: "speed1", 19: "speed2", 20: "speed3", 21: "speed4", 23: "speed5", 22: "speed6"]
        static let equals: UInt16 = 24, minus: UInt16 = 27
        static let left: UInt16 = 123, right: UInt16 = 124, down: UInt16 = 125, up: UInt16 = 126
        static let movement: Set<UInt16> = [a, s, d, w, q, e, equals, minus, left, right, down, up]
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .control, .option])
        guard flags.isEmpty else { super.keyDown(with: event); return }
        if Key.movement.contains(event.keyCode) {
            if !event.isARepeat { heldKeys.insert(event.keyCode) }
            applyHeldKeys()
        } else if event.keyCode == Key.g, !event.isARepeat {
            onToggleGrid?()
        } else if event.keyCode == Key.f, !event.isARepeat {
            onToolKey?("floor")
        } else if event.keyCode == Key.x, !event.isARepeat {
            onToolKey?("demolish")
        } else if event.keyCode == Key.space, !event.isARepeat {
            onToolKey?("pause")
        } else if let speed = Key.digits[event.keyCode], !event.isARepeat {
            onToolKey?(speed)
        } else if event.keyCode == Key.escape {
            isPlacing = false
            worldScene?.cancelPlacement()
            onToolKey?("cancel")
        } else {
            super.keyDown(with: event)
        }
    }

    override func keyUp(with event: NSEvent) {
        if heldKeys.remove(event.keyCode) != nil { applyHeldKeys() } else { super.keyUp(with: event) }
    }

    override func resignFirstResponder() -> Bool {
        heldKeys.removeAll()
        applyHeldKeys()
        return super.resignFirstResponder()
    }

    private func applyHeldKeys() {
        func axis(_ neg: [UInt16], _ pos: [UInt16]) -> Double {
            (pos.contains { heldKeys.contains($0) } ? 1 : 0) - (neg.contains { heldKeys.contains($0) } ? 1 : 0)
        }
        let pan = Vec2(axis([Key.a, Key.left], [Key.d, Key.right]), axis([Key.s, Key.down], [Key.w, Key.up]))
        let zoom = axis([Key.q, Key.minus], [Key.e, Key.equals])
        worldScene?.withController {
            $0.keyboardPan = pan
            $0.keyboardZoom = zoom
        }
    }
}
#endif
