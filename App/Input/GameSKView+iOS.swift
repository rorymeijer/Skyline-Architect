#if os(iOS)
import QuartzCore
import UIKit
import SpriteKit
import SkylineCore
import SkylinePresentation

/// iPad game view: one/two-finger pan with inertia, pinch zoom at the gesture centroid,
/// trackpad scrolling and pointer hover. With a hardware keyboard the same keys as on the
/// Mac work (F4): WASD/arrows pan, Q/E zoom, F, X, G, Space, 1–6 and Esc.
final class GameSKView: SKView, UIGestureRecognizerDelegate {
    var onToggleGrid: (() -> Void)?
    var onToolKey: ((String) -> Void)?
    private var worldScene: WorldScene? { scene as? WorldScene }
    /// True while a one-finger drag places construction (tool active) instead of panning.
    private var isPlacing = false
    /// Movement keys held down (hardware keyboard).
    private var heldKeys = Set<UIKeyboardHIDUsage>()

    override init(frame: CGRect) {
        super.init(frame: frame)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 2
        pan.allowedScrollTypesMask = .continuous
        pan.delegate = self
        addGestureRecognizer(pan)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        addGestureRecognizer(pinch)
        addGestureRecognizer(UIHoverGestureRecognizer(target: self, action: #selector(handleHover(_:))))
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
    }

    /// With a tool active, a tap holds a placement there, and the next taps move its end
    /// (0.30; Place builds it). Without a tool it selects.
    @objc private func handleTap(_ g: UITapGestureRecognizer) {
        guard let worldScene else { return }
        let p = scenePoint(g)
        guard worldScene.activeTool != nil else { worldScene.select(at: p); return }
        worldScene.holdPlacement(at: p)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        worldScene?.backingScale = window?.screen.scale ?? contentScaleFactor
        if window != nil { becomeFirstResponder() }                   // hardware keyboard keys
    }

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

    private func scenePoint(_ g: UIGestureRecognizer) -> CGPoint {
        let p = g.location(in: self)
        guard let scene else { return p }
        return scene.convertPoint(fromView: p)
    }

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        guard let worldScene else { return }
        let time = CACurrentMediaTime()
        // One finger with a construction tool drags out a placement; two fingers always pan.
        if g.state == .began {
            isPlacing = worldScene.activeTool != nil && g.numberOfTouches == 1
        }
        if isPlacing {
            let p = scenePoint(g)
            switch g.state {
            case .began: worldScene.beginPlacement(at: p)
            case .changed: worldScene.updatePlacement(at: p); scrollAtEdge(p)
            case .ended: worldScene.endPlacement(at: p); isPlacing = false; scrollAtEdge(nil)
            default: worldScene.cancelPlacement(); isPlacing = false; scrollAtEdge(nil)
            }
            return
        }
        switch g.state {
        case .began:
            worldScene.withController { $0.beginDrag(at: time) }
        case .changed:
            let t = g.translation(in: self)
            g.setTranslation(.zero, in: self)
            // UIKit y points down; world y points up.
            worldScene.withController { $0.drag(by: Vec2(Double(t.x), -Double(t.y)), at: time) }
        case .ended, .cancelled, .failed:
            worldScene.withController { $0.endDrag(at: time) }
        default:
            break
        }
    }

    /// While a placement is dragged near the edge of the view, the view scrolls that way
    /// (0.30), faster the closer the finger is, so a long room or tall shaft fits in one drag.
    private func scrollAtEdge(_ point: CGPoint?) {
        guard let worldScene else { return }
        var v = Vec2.zero
        if let point, let size = scene?.size {
            let margin = 72.0
            func push(_ distance: Double) -> Double { distance < margin ? min(1, (margin - distance) / margin) * 0.8 : 0 }
            let x = Double(point.x), y = Double(point.y), w = Double(size.width), h = Double(size.height)
            v = Vec2(push(w - x) - push(x), push(h - y) - push(y))       // scene y points up
        }
        guard heldKeys.isEmpty else { return }                           // the keyboard pans
        worldScene.withController { $0.keyboardPan = v }
    }

    @objc private func handlePinch(_ g: UIPinchGestureRecognizer) {
        guard g.state == .changed || g.state == .began else { return }
        let factor = Double(g.scale)
        g.scale = 1
        let point = Vec2(scenePoint(g))
        worldScene?.withController { $0.zoom(by: factor, at: point, animated: false) }
    }

    @objc private func handleHover(_ g: UIHoverGestureRecognizer) {
        switch g.state {
        case .began, .changed: worldScene?.hoverPoint = scenePoint(g)
        default: worldScene?.hoverPoint = nil
        }
    }

    // MARK: Hardware keyboard (F4)

    override var canBecomeFirstResponder: Bool { true }

    private static let panKeys: [UIKeyboardHIDUsage: Vec2] = [
        .keyboardA: Vec2(-1, 0), .keyboardLeftArrow: Vec2(-1, 0), .keyboardD: Vec2(1, 0), .keyboardRightArrow: Vec2(1, 0),
        .keyboardS: Vec2(0, -1), .keyboardDownArrow: Vec2(0, -1), .keyboardW: Vec2(0, 1), .keyboardUpArrow: Vec2(0, 1),
    ]
    private static let zoomKeys: [UIKeyboardHIDUsage: Double] = [
        .keyboardQ: -1, .keyboardHyphen: -1, .keyboardE: 1, .keyboardEqualSign: 1,
    ]
    private static let speedKeys: [UIKeyboardHIDUsage: String] = [
        .keyboard1: "speed1", .keyboard2: "speed2", .keyboard3: "speed3", .keyboard4: "speed4", .keyboard5: "speed5", .keyboard6: "speed6",
    ]

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var unhandled = Set<UIPress>()
        for press in presses {
            guard let key = press.key, key.modifierFlags.intersection([.command, .control, .alternate]).isEmpty else {
                unhandled.insert(press); continue
            }
            let code = key.keyCode
            if Self.panKeys[code] != nil || Self.zoomKeys[code] != nil {
                heldKeys.insert(code)
                applyHeldKeys()
            } else if code == .keyboardG {
                onToggleGrid?()
            } else if code == .keyboardF {
                onToolKey?("floor")
            } else if code == .keyboardX {
                onToolKey?("demolish")
            } else if code == .keyboardSpacebar {
                onToolKey?("pause")
            } else if let speed = Self.speedKeys[code] {
                onToolKey?(speed)
            } else if code == .keyboardEscape {
                isPlacing = false
                worldScene?.cancelPlacement()
                onToolKey?("cancel")
            } else {
                unhandled.insert(press)
            }
        }
        if !unhandled.isEmpty { super.pressesBegan(unhandled, with: event) }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var unhandled = Set<UIPress>()
        for press in presses {
            if let code = press.key?.keyCode, heldKeys.remove(code) != nil { applyHeldKeys() } else { unhandled.insert(press) }
        }
        if !unhandled.isEmpty { super.pressesEnded(unhandled, with: event) }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        heldKeys.removeAll()
        applyHeldKeys()
        super.pressesCancelled(presses, with: event)
    }

    private func applyHeldKeys() {
        var pan = Vec2(0, 0)
        var zoom = 0.0
        for key in heldKeys {
            if let p = Self.panKeys[key] { pan = Vec2(pan.x + p.x, pan.y + p.y) }
            if let z = Self.zoomKeys[key] { zoom += z }
        }
        let clampedPan = Vec2(min(max(pan.x, -1), 1), min(max(pan.y, -1), 1))
        let clampedZoom = min(max(zoom, -1), 1)
        worldScene?.withController {
            $0.keyboardPan = clampedPan
            $0.keyboardZoom = clampedZoom
        }
    }
}
#endif
