import SpriteKit
import SkylineCore
import SkylinePresentation
import SkylineSimulation

/// Player overlay for elevator traffic (⌥⌘T): a badge per landing queue (count, coloured by
/// the longest wait), each car's load, and a label per bank with its strategy and average
/// wait. Screen space, pooled nodes; draws `ElevatorTraffic` data only.
final class TrafficOverlayNode: SKNode {
    private var badges: [SKNode] = []
    private var loads: [SKNode] = []
    private var labels: [SKNode] = []

    override init() {
        super.init()
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    func update(traffic: ElevatorTraffic?, camera: Camera2D) {
        guard let traffic else { isHidden = true; return }
        isHidden = false
        layout(&badges, count: traffic.queues.count) { node, i in
            let q = traffic.queues[i]
            let p = camera.worldToScreen(q.position + Vec2(0, 2.4)).cgPoint
            node.position = p
            let color: SKColor = q.longestWait < 30 ? SKColor(red: 0.30, green: 0.75, blue: 0.40, alpha: 0.95)
                : q.longestWait < 60 ? SKColor(red: 0.95, green: 0.70, blue: 0.20, alpha: 0.95)
                : SKColor(red: 0.90, green: 0.30, blue: 0.25, alpha: 0.95)
            Self.setText(node, "\(q.count) · \(q.longestWait)s", fill: color, textColor: .white)
        }
        layout(&loads, count: traffic.cars.count) { node, i in
            let c = traffic.cars[i]
            node.position = camera.worldToScreen(c.position + Vec2(0, 0.5)).cgPoint
            Self.setText(node, "\(c.load)/\(c.capacity)", fill: SKColor(white: 0.08, alpha: 0.8), textColor: .white)
        }
        layout(&labels, count: traffic.banks.count) { node, i in
            let b = traffic.banks[i]
            node.position = camera.worldToScreen(b.position + Vec2(0, 12 / camera.zoom)).cgPoint
            Self.setText(node, "Bank \(b.name) · \(b.strategy.rawValue) · avg \(Int(b.stats.averageWait.rounded())) s",
                         fill: SKColor(red: 0.12, green: 0.30, blue: 0.45, alpha: 0.9), textColor: .white)
        }
    }

    private func layout(_ pool: inout [SKNode], count: Int, _ configure: (SKNode, Int) -> Void) {
        while pool.count < count { pool.append(makeTag()) }
        for (i, node) in pool.enumerated() {
            node.isHidden = i >= count
            if i < count { configure(node, i) }
        }
    }

    private func makeTag() -> SKNode {
        let container = SKNode()
        let bg = SKShapeNode()
        bg.name = "bg"
        bg.strokeColor = SKColor(white: 1, alpha: 0.25)
        container.addChild(bg)
        let text = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        text.name = "text"
        text.fontSize = 10
        text.horizontalAlignmentMode = .center
        text.verticalAlignmentMode = .center
        container.addChild(text)
        addChild(container)
        return container
    }

    private static func setText(_ node: SKNode, _ string: String, fill: SKColor, textColor: SKColor) {
        guard let text = node.childNode(withName: "text") as? SKLabelNode, let bg = node.childNode(withName: "bg") as? SKShapeNode else { return }
        text.fontColor = textColor
        bg.fillColor = fill
        guard text.text != string else { return }
        text.text = string
        let w = text.frame.width + 12
        bg.path = CGPath(roundedRect: CGRect(x: -w / 2, y: -8, width: w, height: 16), cornerWidth: 8, cornerHeight: 8, transform: nil)
    }
}

