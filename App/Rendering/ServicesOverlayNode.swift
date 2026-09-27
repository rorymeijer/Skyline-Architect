import SpriteKit
import SkylineCore
import SkylinePresentation
import SkylineSimulation

/// Services overlay (⌥⌘U): every room tinted by its worst problem — red out of order,
/// orange missing utilities, amber worn, blue dirty; fine rooms get a faint green.
final class ServicesOverlayNode: SKNode {
    private var pool: [SKShapeNode] = []

    override init() {
        super.init()
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    static func color(_ s: ServiceMark.Status) -> SKColor {
        switch s {
        case .ok: SKColor(red: 0.3, green: 0.8, blue: 0.4, alpha: 0.12)
        case .dirty: SKColor(red: 0.35, green: 0.6, blue: 0.95, alpha: 0.35)
        case .worn: SKColor(red: 0.95, green: 0.75, blue: 0.2, alpha: 0.38)
        case .short: SKColor(red: 0.98, green: 0.5, blue: 0.15, alpha: 0.45)
        case .broken: SKColor(red: 0.9, green: 0.15, blue: 0.15, alpha: 0.55)
        }
    }

    func update(marks: [ServiceMark]?, camera: Camera2D) {
        guard let marks else { isHidden = true; return }
        isHidden = false
        while pool.count < marks.count {
            let n = SKShapeNode()
            n.lineWidth = 1
            addChild(n)
            pool.append(n)
        }
        for (i, node) in pool.enumerated() {
            guard i < marks.count else { node.isHidden = true; continue }
            let m = marks[i]
            let a = camera.worldToScreen(Vec2(m.rect.minX, m.rect.minY)), b = camera.worldToScreen(Vec2(m.rect.maxX, m.rect.maxY))
            node.path = CGPath(rect: CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y).insetBy(dx: 1, dy: 1), transform: nil)
            node.fillColor = Self.color(m.status)
            node.strokeColor = Self.color(m.status).withAlphaComponent(0.9)
            node.isHidden = false
        }
    }
}
