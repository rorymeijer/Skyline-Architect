import SpriteKit
import SkylineCore
import SkylinePresentation

/// Basic day/night (Phase 9): a screen-sized multiply tint over the world and additive warm
/// light over rooms that are lit from inside. Pure view of `DayNight` data.
final class DayNightLayer {
    /// Scene child (screen space), above the world, below overlays.
    let tint = SKSpriteNode(color: .white, size: .zero)
    /// World child: lit rooms.
    let lights = SKNode()
    private var pool: [SKSpriteNode] = []
    private static let lamp = SKColor(red: 1.0, green: 0.82, blue: 0.52, alpha: 1)

    init() {
        tint.anchorPoint = .zero
        tint.blendMode = .multiply
        tint.isHidden = true
    }

    func update(daylight: Double, rooms: [LitRoom], viewport: CGSize) {
        tint.size = viewport
        tint.isHidden = daylight >= 0.999
        let c = DayNight.ambient(daylight: daylight)
        tint.color = SKColor(red: c.r, green: c.g, blue: c.b, alpha: 1)
        while pool.count < rooms.count {
            let s = SKSpriteNode(color: Self.lamp, size: .zero)
            s.anchorPoint = .zero
            s.blendMode = .add
            lights.addChild(s)
            pool.append(s)
        }
        for (i, sprite) in pool.enumerated() {
            guard i < rooms.count else { sprite.isHidden = true; continue }
            let r = rooms[i].rect
            sprite.isHidden = false
            sprite.position = CGPoint(x: r.minX + 0.1, y: r.minY)
            sprite.size = CGSize(width: max(r.width - 0.2, 0), height: max(r.height - 0.45, 0))
            sprite.alpha = CGFloat(0.42 * rooms[i].intensity)
        }
    }
}
