#if os(iOS)
import QuartzCore
import UIKit
import SpriteKit
import SkylineCore
import SkylinePresentation

/// iPad game view: one/two-finger pan with inertia, pinch zoom at the gesture centroid,
/// trackpad scrolling and pointer hover. Interaction is designed for touch; construction
/// tools (Phase 2) will add contextual controls rather than reuse macOS mouse semantics.
final class GameSKView: SKView, UIGestureRecognizerDelegate {
    var onToggleGrid: (() -> Void)?
    var onToolKey: ((String) -> Void)?
    private var worldScene: WorldScene? { scene as? WorldScene }
    /// True while a one-finger drag places construction (tool active) instead of panning.
    private var isPlacing = false

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

    /// With a tool active, a tap places at the default size; otherwise it selects.
    @objc private func handleTap(_ g: UITapGestureRecognizer) {
        guard let worldScene else { return }
        let p = scenePoint(g)
        guard worldScene.activeTool != nil else { worldScene.select(at: p); return }
        worldScene.beginPlacement(at: p)
        worldScene.endPlacement(at: p)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        worldScene?.backingScale = window?.screen.scale ?? contentScaleFactor
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
            case .changed: worldScene.updatePlacement(at: p)
            case .ended: worldScene.endPlacement(at: p); isPlacing = false
            default: worldScene.cancelPlacement(); isPlacing = false
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
}
#endif
