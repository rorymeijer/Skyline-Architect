import CoreGraphics
import SpriteKit
import SkylineCore
import SkylinePresentation

/// Day/night (Phases 9, 12): a screen-sized multiply grade (vertical gradient) over the
/// world, additive coloured light over lit rooms or their window panes, and the opacity of
/// the static emission tiles (city windows, street lamps). Pure view of `DayNight` data.
final class DayNightLayer {
    /// Scene child (screen space), above the world, below overlays.
    let tint = SKSpriteNode(color: .white, size: .zero)
    /// World child: lit rooms.
    let lights = SKNode()
    private var pool: [SKSpriteNode] = []
    private var gradeKey: [Int] = []

    init() {
        tint.anchorPoint = .zero
        tint.blendMode = .multiply
        tint.isHidden = true
    }

    /// `emission` (city windows) and `lamps` (street lamps) are the nodes of the static
    /// light tile layers, faded in with the darkness; windows also follow `cityActivity`.
    func update(grade: Grade, darkness: Double, cityActivity: Double, rooms: [LitRoom], viewport: CGSize, emission: SKNode, lamps: SKNode) {
        tint.size = viewport
        let plain = grade == .day
        tint.isHidden = plain
        if !plain { applyGrade(grade) }
        let night = min(max(darkness * 1.1 - 0.05, 0), 1)
        emission.alpha = CGFloat(night * cityActivity)
        emission.isHidden = emission.alpha < 0.01
        lamps.alpha = CGFloat(night)
        lamps.isHidden = lamps.alpha < 0.01
        while pool.count < rooms.count {
            let s = SKSpriteNode(color: .white, size: .zero)
            s.anchorPoint = .zero
            s.blendMode = .add
            lights.addChild(s)
            pool.append(s)
        }
        for (i, sprite) in pool.enumerated() {
            guard i < rooms.count else { sprite.isHidden = true; continue }
            let room = rooms[i], r = room.rect
            let pane = r.height < 3                                    // window panes: no inset, brighter
            sprite.isHidden = false
            sprite.color = SKColor(red: room.color.r, green: room.color.g, blue: room.color.b, alpha: 1)
            sprite.position = CGPoint(x: r.minX + (pane ? 0 : 0.1), y: r.minY)
            sprite.size = CGSize(width: max(r.width - (pane ? 0 : 0.2), 0), height: max(r.height - (pane ? 0 : 0.45), 0))
            sprite.alpha = CGFloat((pane ? 0.75 : 0.42) * room.intensity)
        }
    }

    /// Rebuilds the gradient texture only when the grade visibly changes.
    private func applyGrade(_ g: Grade) {
        let key = [g.top.r, g.top.g, g.top.b, g.bottom.r, g.bottom.g, g.bottom.b].map { Int(($0 * 200).rounded()) }
        guard key != gradeKey else { return }
        gradeKey = key
        let height = 64
        guard let ctx = CGContext(data: nil, width: 1, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        for y in 0..<height {
            let t = Double(y) / Double(height - 1)                     // 0 = bottom (horizon), 1 = top
            let c = g.bottom.mixed(with: g.top, t)
            ctx.setFillColor(red: c.r, green: c.g, blue: c.b, alpha: 1)
            ctx.fill(CGRect(x: 0, y: y, width: 1, height: 1))
        }
        guard let image = ctx.makeImage() else { return }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .linear
        tint.texture = texture
        tint.color = .white
        tint.colorBlendFactor = 0
    }
}
