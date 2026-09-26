import SpriteKit
import SkylineCore
import SkylinePresentation

/// Screen-space architectural grid, floor labels and hover cell. Rebuilt only when the
/// camera or hover changes; line count is bounded by `ArchitecturalGrid` strides.
final class GridOverlayNode: SKNode {
    private var lineNodes: [GridLineStyle: SKShapeNode] = [:]
    private let hoverNode = SKShapeNode()
    private var labelPool: [SKNode] = []
    private let palette: ArtPalette

    init(palette: ArtPalette) {
        self.palette = palette
        super.init()
        for style in GridLineStyle.allCases {
            let n = SKShapeNode()
            n.zPosition = 10 + CGFloat(style.rawValue) * 0.01
            n.isAntialiased = true
            n.lineCap = .butt
            let (color, width) = Self.appearance(style, palette)
            n.strokeColor = color.skColor
            n.lineWidth = width
            addChild(n)
            lineNodes[style] = n
        }
        hoverNode.zPosition = 11
        hoverNode.fillColor = palette.hoverCell.skColor
        hoverNode.strokeColor = palette.gridGrade.skColor
        hoverNode.lineWidth = 1
        addChild(hoverNode)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    static func appearance(_ s: GridLineStyle, _ p: ArtPalette) -> (RGBA, CGFloat) {
        switch s {
        case .module: (p.gridModule, 1)
        case .bay: (p.gridBay, 1)
        case .floor: (p.gridFloor, 1)
        case .floorMajor: (p.gridFloorMajor, 1.5)
        case .grade: (p.gridGrade, 1.5)
        case .plotBoundary: (p.plotBoundary, 1.5)
        }
    }

    /// - Parameters:
    ///   - backingScale: used to snap lines to device pixels for crisp 1 px strokes.
    ///   - frontageMinX: world x of the plot's left edge (labels sit just left of it).
    func update(overlay: GridOverlay, camera: Camera2D, backingScale: CGFloat, frontageMinX: Double, hoverRect: Rect?) {
        func snap(_ v: Double) -> CGFloat {
            let s = Double(backingScale)
            return CGFloat(((v * s).rounded(.down) + 0.5) / s)
        }
        var paths: [GridLineStyle: CGMutablePath] = [:]
        for line in overlay.lines {
            let a = camera.worldToScreen(line.from), b = camera.worldToScreen(line.to)
            let path = paths[line.style] ?? CGMutablePath()
            if a.x == b.x || abs(a.x - b.x) < 0.01 {
                path.move(to: CGPoint(x: snap(a.x), y: a.y))
                path.addLine(to: CGPoint(x: snap(b.x), y: b.y))
            } else {
                path.move(to: CGPoint(x: a.x, y: snap(a.y)))
                path.addLine(to: CGPoint(x: b.x, y: snap(b.y)))
            }
            paths[line.style] = path
        }
        for (style, node) in lineNodes {
            var path: CGPath = paths[style] ?? CGMutablePath()
            if style == .plotBoundary, paths[style] != nil {
                path = path.copy(dashingWithPhase: 0, lengths: [6, 4])
            }
            node.path = path
        }

        if let hoverRect {
            let a = camera.worldToScreen(Vec2(hoverRect.minX, hoverRect.minY))
            let b = camera.worldToScreen(Vec2(hoverRect.maxX, hoverRect.maxY))
            hoverNode.path = CGPath(rect: CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y), transform: nil)
            hoverNode.isHidden = false
        } else {
            hoverNode.isHidden = true
        }

        updateLabels(overlay.labels, camera: camera, frontageMinX: frontageMinX)
    }

    private func updateLabels(_ labels: [GridLabel], camera: Camera2D, frontageMinX: Double) {
        while labelPool.count < labels.count { labelPool.append(makeLabel()) }
        let edge = camera.worldToScreen(Vec2(frontageMinX, 0)).x
        let x = CGFloat(max(edge - 8, 34))
        for (i, node) in labelPool.enumerated() {
            guard i < labels.count else { node.isHidden = true; continue }
            let label = labels[i]
            node.isHidden = false
            node.position = CGPoint(x: x, y: camera.worldToScreen(Vec2(0, label.y)).y)
            if let text = node.childNode(withName: "text") as? SKLabelNode, text.text != label.text {
                text.text = label.text
                if let bg = node.childNode(withName: "bg") as? SKShapeNode {
                    let w = text.frame.width + 8
                    bg.path = CGPath(roundedRect: CGRect(x: -w + 3, y: -8, width: w, height: 16),
                                     cornerWidth: 4, cornerHeight: 4, transform: nil)
                }
            }
        }
    }

    private func makeLabel() -> SKNode {
        let container = SKNode()
        container.zPosition = 12
        let bg = SKShapeNode()
        bg.name = "bg"
        bg.fillColor = SKColor(white: 0, alpha: 0.42)
        bg.strokeColor = .clear
        container.addChild(bg)
        let text = SKLabelNode(fontNamed: "Menlo-Bold")
        text.name = "text"
        text.fontSize = 10
        text.fontColor = palette.gridLabel.skColor
        text.horizontalAlignmentMode = .right
        text.verticalAlignmentMode = .center
        text.position = CGPoint(x: -1, y: 0)
        container.addChild(text)
        addChild(container)
        return container
    }
}
