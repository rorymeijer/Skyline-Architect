import CoreGraphics
import SpriteKit
import SkylineCore
import SkylinePresentation

/// Fire (Phase 14): flames glowing up from the floor of burning rooms, smoke under their
/// ceilings, and fire engines at the kerb once the brigade is there. A pure view of
/// `FireView` data (world space).
final class FireLayer {
    let node = SKNode()
    private var flames: [(glow: SKSpriteNode, smoke: SKSpriteNode, spray: SKSpriteNode)] = []
    private var soot: [SKSpriteNode] = []
    private var engines: [SKNode] = []
    private let flameTexture = FireLayer.gradient(bottom: (1, 0.55, 0.12, 1), top: (1, 0.25, 0.05, 0))
    private let smokeTexture = FireLayer.gradient(bottom: (0.15, 0.14, 0.14, 0), top: (0.12, 0.11, 0.11, 1))
    private let sprayTexture = FireLayer.streaks()

    func update(flames marks: [FlameMark], engines positions: [Vec2], scorched: [ScorchMark]) {
        while soot.count < scorched.count {
            let s = SKSpriteNode(color: SKColor(red: 0.08, green: 0.07, blue: 0.06, alpha: 1), size: .zero)
            s.anchorPoint = .zero
            node.addChild(s)
            soot.append(s)
        }
        for (i, s) in soot.enumerated() {
            s.isHidden = i >= scorched.count
            guard i < scorched.count else { continue }
            let r = scorched[i].rect
            s.position = CGPoint(x: r.minX + 0.1, y: r.minY + 0.05)
            s.size = CGSize(width: r.width - 0.2, height: r.height - 0.45)
            s.alpha = CGFloat(0.6 * scorched[i].soot)
        }
        while flames.count < marks.count {
            let glow = SKSpriteNode(texture: flameTexture)
            glow.anchorPoint = .zero
            glow.blendMode = .add
            let smoke = SKSpriteNode(texture: smokeTexture)
            smoke.anchorPoint = .zero
            let spray = SKSpriteNode(texture: sprayTexture)
            spray.anchorPoint = .zero
            spray.blendMode = .add
            node.addChild(glow)
            node.addChild(smoke)
            node.addChild(spray)
            flames.append((glow, smoke, spray))
        }
        for (i, pair) in flames.enumerated() {
            guard i < marks.count else { pair.glow.isHidden = true; pair.smoke.isHidden = true; pair.spray.isHidden = true; continue }
            pair.spray.isHidden = !marks[i].sprinklers
            pair.spray.position = CGPoint(x: marks[i].rect.minX + 0.1, y: marks[i].rect.minY + 0.1)
            pair.spray.size = CGSize(width: marks[i].rect.width - 0.2, height: marks[i].rect.height - 0.5)
            pair.spray.alpha = 0.55
            let m = marks[i], r = m.rect
            pair.glow.isHidden = false
            pair.glow.position = CGPoint(x: r.minX + 0.1, y: r.minY + 0.1)
            pair.glow.size = CGSize(width: r.width - 0.2, height: (r.height - 0.5) * (0.35 + 0.55 * m.intensity) * m.flicker)
            pair.glow.alpha = CGFloat(min(1, 0.35 + 0.75 * m.intensity))
            pair.smoke.isHidden = false
            let depth = (r.height - 0.4) * (0.25 + 0.5 * m.intensity)
            pair.smoke.position = CGPoint(x: r.minX + 0.1, y: r.maxY - 0.4 - depth)
            pair.smoke.size = CGSize(width: r.width - 0.2, height: depth)
            pair.smoke.alpha = CGFloat(0.35 + 0.5 * m.intensity)
        }
        while engines.count < positions.count {
            let e = FireLayer.fireEngine()
            node.addChild(e)
            engines.append(e)
        }
        for (i, e) in engines.enumerated() {
            e.isHidden = i >= positions.count
            if i < positions.count { e.position = CGPoint(x: positions[i].x, y: positions[i].y) }
        }
    }

    /// A simple side view of a fire engine (9 m long), rear at the origin.
    private static func fireEngine() -> SKNode {
        let n = SKNode()
        func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: SKColor) {
            let s = SKSpriteNode(color: c, size: CGSize(width: w, height: h))
            s.anchorPoint = .zero
            s.position = CGPoint(x: x, y: y)
            n.addChild(s)
        }
        let red = SKColor(red: 0.72, green: 0.10, blue: 0.08, alpha: 1)
        box(0, 0.55, 9, 2.1, red)                                         // body
        box(6.6, 0.55, 2.4, 2.7, red)                                     // cab
        box(7.3, 2.0, 1.5, 0.9, SKColor(red: 0.55, green: 0.7, blue: 0.8, alpha: 1))   // windscreen
        box(0.3, 2.65, 5.8, 0.18, SKColor(white: 0.8, alpha: 1))          // ladder
        box(0.3, 1.2, 6.0, 0.12, SKColor(white: 0.95, alpha: 1))          // stripe
        box(7.6, 3.25, 0.6, 0.15, SKColor(red: 0.2, green: 0.4, blue: 1, alpha: 1))    // beacon
        for x: CGFloat in [1.2, 2.6, 7.2] {
            let wheel = SKShapeNode(circleOfRadius: 0.5)
            wheel.fillColor = SKColor(white: 0.12, alpha: 1)
            wheel.strokeColor = .clear
            wheel.position = CGPoint(x: x, y: 0.5)
            n.addChild(wheel)
        }
        return n
    }

    /// Sprinkler spray: faint blue streaks falling from the ceiling.
    private static func streaks() -> SKTexture {
        let w = 64, h = 64
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return SKTexture() }
        var rng = SeededRandom(seed: 0x5B1)
        for _ in 0..<70 {
            let x = rng.int(in: 0..<w), y = rng.int(in: 8..<h), len = rng.int(in: 4..<12)
            let a = CGFloat(rng.double(in: 0.25..<0.6))
            ctx.setFillColor(red: 0.55 * a, green: 0.75 * a, blue: 1.0 * a, alpha: a)
            ctx.fill(CGRect(x: x, y: y - len, width: 1, height: len))
        }
        return ctx.makeImage().map { SKTexture(cgImage: $0) } ?? SKTexture()
    }

    private static func gradient(bottom: (CGFloat, CGFloat, CGFloat, CGFloat), top: (CGFloat, CGFloat, CGFloat, CGFloat)) -> SKTexture {
        let h = 32
        guard let ctx = CGContext(data: nil, width: 1, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return SKTexture() }
        for y in 0..<h {
            let t = CGFloat(y) / CGFloat(h - 1)
            let a = bottom.3 + (top.3 - bottom.3) * t
            ctx.setFillColor(red: (bottom.0 + (top.0 - bottom.0) * t) * a, green: (bottom.1 + (top.1 - bottom.1) * t) * a,
                             blue: (bottom.2 + (top.2 - bottom.2) * t) * a, alpha: a)
            ctx.fill(CGRect(x: 0, y: y, width: 1, height: 1))
        }
        return ctx.makeImage().map { SKTexture(cgImage: $0) } ?? SKTexture()
    }
}
