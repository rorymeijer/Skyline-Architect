import SpriteKit
import SkylineCore
import SkylinePresentation

/// Screen-space construction feedback: a ghost of the target cells (green = valid,
/// red = refused, amber = demolition) and a label with name, size and cost or the reason
/// the placement is refused.
final class PlacementOverlayNode: SKNode {
    private let ghost = SKShapeNode()
    private let labelBackground = SKShapeNode()
    private let label = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
    private let palette: ArtPalette

    init(palette: ArtPalette) {
        self.palette = palette
        super.init()
        ghost.zPosition = 0
        ghost.lineWidth = 1.5
        addChild(ghost)
        labelBackground.zPosition = 1
        labelBackground.strokeColor = .clear
        labelBackground.fillColor = SKColor(white: 0.05, alpha: 0.78)
        addChild(labelBackground)
        label.zPosition = 2
        label.fontSize = 12
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        addChild(label)
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    func update(preview: PlacementPreview?, camera: Camera2D, cursor: CGPoint?) {
        guard let preview else { isHidden = true; return }
        isHidden = false
        let a = camera.worldToScreen(Vec2(preview.rect.minX, preview.rect.minY))
        let b = camera.worldToScreen(Vec2(preview.rect.maxX, preview.rect.maxY))
        ghost.path = CGPath(rect: CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y), transform: nil)
        let (fill, edge): (RGBA, RGBA) = !preview.isValid ? (palette.previewInvalid, palette.previewInvalidEdge)
            : preview.isDemolition ? (palette.previewDemolish, palette.previewInvalidEdge.mixed(with: palette.previewDemolish, 0.5))
            : (palette.previewValid, palette.previewValidEdge)
        ghost.fillColor = fill.skColor
        ghost.strokeColor = edge.withAlpha(1).skColor

        label.text = preview.label
        label.fontColor = preview.isValid ? .white : edge.withAlpha(1).mixed(with: .white, 0.35).skColor
        // Place the label next to the cursor (or above the ghost), kept on screen.
        let anchor = cursor ?? CGPoint(x: a.x, y: b.y)
        let size = label.frame.size
        let viewport = camera.viewportSize
        let x = min(max(anchor.x + 16, 8), CGFloat(viewport.x) - size.width - 16)
        let y = min(max(anchor.y + 22, 16), CGFloat(viewport.y) - 16)
        label.position = CGPoint(x: x, y: y)
        labelBackground.path = CGPath(roundedRect: CGRect(x: x - 8, y: y - 11, width: size.width + 16, height: 22),
                                      cornerWidth: 6, cornerHeight: 6, transform: nil)
    }
}

/// Room names over rooms at readable zoom levels (screen space, pooled labels).
final class RoomLabelLayer: SKNode {
    private var pool: [SKNode] = []

    func update(labels: [RoomLabel], camera: Camera2D) {
        while pool.count < labels.count { pool.append(makeLabel()) }
        for (i, node) in pool.enumerated() {
            guard i < labels.count else { node.isHidden = true; continue }
            node.isHidden = false
            node.position = camera.worldToScreen(labels[i].position).cgPoint
            guard let text = node.childNode(withName: "text") as? SKLabelNode, text.text != labels[i].text else { continue }
            text.text = labels[i].text
            if let bg = node.childNode(withName: "bg") as? SKShapeNode {
                let w = text.frame.width + 10
                bg.path = CGPath(roundedRect: CGRect(x: -w / 2, y: -8, width: w, height: 16), cornerWidth: 5, cornerHeight: 5, transform: nil)
            }
        }
    }

    private func makeLabel() -> SKNode {
        let container = SKNode()
        let bg = SKShapeNode()
        bg.name = "bg"
        bg.fillColor = SKColor(white: 1, alpha: 0.72)
        bg.strokeColor = .clear
        container.addChild(bg)
        let text = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
        text.name = "text"
        text.fontSize = 10
        text.fontColor = SKColor(white: 0.12, alpha: 1)
        text.horizontalAlignmentMode = .center
        text.verticalAlignmentMode = .center
        container.addChild(text)
        addChild(container)
        return container
    }
}
