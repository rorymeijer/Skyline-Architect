import SpriteKit
import SkylineCore
import SkylinePresentation

/// Draws visible people as sprites in world space. Positions come from `PeopleView`
/// (analytic, evaluated at the fractional render time); the layer only pools nodes and
/// caches figure textures per look/pose/frame. Never authoritative state.
final class AgentLayer {
    let node = SKNode()
    private var sprites: [PersonID: SKSpriteNode] = [:]
    private var textures: [String: SKTexture] = [:]
    /// Figure raster density (pixels per meter).
    private let pixelsPerMeter = 96.0
    private(set) var renderedCount = 0

    func update(_ visible: [PersonSprite]) {
        var seen = Set<PersonID>()
        seen.reserveCapacity(visible.count)
        for s in visible {
            seen.insert(s.id)
            let sprite = sprites[s.id] ?? makeSprite(s.id)
            sprite.texture = texture(for: s)
            sprite.position = CGPoint(x: s.position.x, y: s.position.y)
            sprite.xScale = s.facing >= 0 ? 1 : -1
            sprite.isHidden = false
        }
        for (id, sprite) in sprites where !seen.contains(id) {
            sprite.removeFromParent()
            sprites.removeValue(forKey: id)
        }
        renderedCount = visible.count
    }

    private func makeSprite(_ id: PersonID) -> SKSpriteNode {
        let sprite = SKSpriteNode(color: .clear, size: CGSize(width: PersonArt.width, height: PersonArt.height))
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        sprite.zPosition = 5
        node.addChild(sprite)
        sprites[id] = sprite
        return sprite
    }

    private func texture(for s: PersonSprite) -> SKTexture? {
        let key = "\(s.look.key)-\(s.pose.rawValue)-\(s.frame)"
        if let t = textures[key] { return t }
        let drawing = PersonArt.figure(s.look, pose: s.pose, frame: s.frame)
        guard let image = DrawingRasterizer.rasterize(drawing, rect: Rect(x: 0, y: 0, width: PersonArt.width, height: PersonArt.height),
                                                      pixelsPerMeter: pixelsPerMeter) else { return nil }
        let t = SKTexture(cgImage: image)
        t.filteringMode = .linear
        textures[key] = t
        return t
    }
}
