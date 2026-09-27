import SpriteKit
import SkylineCore
import SkylinePresentation
import SkylineSimulation

/// Developer overlay (⌥⌘N, Debug builds): the navigation graph — portals, walk links along
/// floors, stair links (orange) and elevator links (green) between storeys — and the
/// remaining route of every traveller.
/// Screen space, rebuilt per frame while visible; it only draws `NavigationOverlay` data.
final class NavigationOverlayNode: SKNode {
    private let walkLinks = SKShapeNode()
    private let stairLinks = SKShapeNode()
    private let elevatorLinks = SKShapeNode()
    private let routes = SKShapeNode()
    private let portals = SKShapeNode()

    override init() {
        super.init()
        routes.strokeColor = SKColor(red: 1.0, green: 0.30, blue: 0.62, alpha: 0.75)
        routes.lineWidth = 1.5
        walkLinks.strokeColor = SKColor(red: 0.30, green: 0.85, blue: 1.0, alpha: 0.85)
        walkLinks.lineWidth = 2
        stairLinks.strokeColor = SKColor(red: 1.0, green: 0.72, blue: 0.20, alpha: 0.95)
        stairLinks.lineWidth = 3
        elevatorLinks.strokeColor = SKColor(red: 0.45, green: 0.95, blue: 0.45, alpha: 0.95)
        elevatorLinks.lineWidth = 3
        portals.fillColor = SKColor(red: 1.0, green: 0.93, blue: 0.55, alpha: 1)
        portals.strokeColor = SKColor(white: 0.05, alpha: 0.9)
        portals.lineWidth = 1
        for (z, node) in [routes, walkLinks, stairLinks, elevatorLinks, portals].enumerated() {
            node.zPosition = CGFloat(z)
            node.lineCap = .round
            node.lineJoin = .round
            addChild(node)
        }
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    func update(overlay: NavigationOverlay?, camera: Camera2D) {
        guard let overlay else { isHidden = true; return }
        isHidden = false
        func p(_ v: Vec2) -> CGPoint { camera.worldToScreen(v).cgPoint }
        func segments(_ list: [NavigationOverlay.Segment]) -> CGPath {
            let path = CGMutablePath()
            for s in list {
                path.move(to: p(s.a))
                path.addLine(to: p(s.b))
            }
            return path
        }
        walkLinks.path = segments(overlay.walkLinks)
        stairLinks.path = segments(overlay.stairLinks)
        elevatorLinks.path = segments(overlay.elevatorLinks)
        let routePath = CGMutablePath()
        for line in overlay.routes {
            routePath.addLines(between: line.map(p))
        }
        routes.path = routePath
        let dots = CGMutablePath()
        let r = CGFloat(min(max(camera.zoom * 0.35, 2.5), 6))
        for v in overlay.portals {
            let c = p(v)
            dots.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        }
        portals.path = dots
    }
}
