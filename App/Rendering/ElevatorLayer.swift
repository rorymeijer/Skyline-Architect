import SpriteKit
import SkylineCore
import SkylinePresentation

/// Draws visible elevator cars (cab + hoist rope) in world space, below the people layer so
/// riders appear inside the cab. Positions come from `ElevatorView`; cab textures are cached
/// per width and door step. Never authoritative state.
final class ElevatorLayer {
    let node = SKNode()
    private var cabs: [RoomID: (cab: SKSpriteNode, rope: SKSpriteNode)] = [:]
    private var textures: [String: SKTexture] = [:]
    private let pixelsPerMeter = 64.0

    func update(_ visible: [CarSprite]) {
        var seen = Set<RoomID>()
        for s in visible {
            seen.insert(s.id)
            let nodes = cabs[s.id] ?? makeNodes(s.id)
            nodes.cab.texture = texture(width: s.rect.width, step: s.doorStep)
            nodes.cab.size = CGSize(width: s.rect.width, height: s.rect.height + 0.42)
            nodes.cab.position = CGPoint(x: s.rect.minX, y: s.rect.minY - 0.12)
            let ropeBottom = s.rect.maxY + 0.3
            nodes.rope.position = CGPoint(x: s.rect.midX, y: ropeBottom)
            nodes.rope.size = CGSize(width: 0.05, height: max(s.ropeTop - ropeBottom, 0))
        }
        for (id, nodes) in cabs where !seen.contains(id) {
            nodes.cab.removeFromParent()
            nodes.rope.removeFromParent()
            cabs.removeValue(forKey: id)
        }
    }

    private func makeNodes(_ id: RoomID) -> (cab: SKSpriteNode, rope: SKSpriteNode) {
        let cab = SKSpriteNode(color: .clear, size: .zero)
        cab.anchorPoint = .zero
        cab.zPosition = 4
        let rope = SKSpriteNode(color: SKColor(white: 0.12, alpha: 0.9), size: .zero)
        rope.anchorPoint = CGPoint(x: 0.5, y: 0)
        rope.zPosition = 3.9
        node.addChild(rope)
        node.addChild(cab)
        cabs[id] = (cab, rope)
        return (cab, rope)
    }

    /// Cab texture covering x 0…width, y −0.12…cabHeight + 0.3 (sill below, crosshead above).
    private func texture(width: Double, step: Int) -> SKTexture? {
        let key = String(format: "%.2f-%d", width, step)
        if let t = textures[key] { return t }
        let drawing = ElevatorArt.cab(width: width, opening: Double(step) / Double(ElevatorArt.doorSteps))
        let rect = Rect(x: 0, y: -0.12, width: width, height: ElevatorArt.cabHeight + 0.42)
        guard let image = DrawingRasterizer.rasterize(drawing, rect: rect, pixelsPerMeter: pixelsPerMeter) else { return nil }
        let t = SKTexture(cgImage: image)
        t.filteringMode = .linear
        textures[key] = t
        return t
    }
}
