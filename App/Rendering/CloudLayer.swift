import CoreGraphics
import SpriteKit
import SkylinePresentation

/// Clouds between the sky gradient and the skyline (Phase 20): pooled soft sprites placed
/// from `CloudView` data, tinted by the time of day. A pure view.
final class CloudLayer {
    let node = SKNode()
    private var sprites: [SKSpriteNode] = []
    private let texture = CloudLayer.puff()

    func update(_ clouds: [CloudPuff], darkness: Double) {
        while sprites.count < clouds.count {
            let s = SKSpriteNode(texture: texture)
            s.colorBlendFactor = 1
            node.addChild(s)
            sprites.append(s)
        }
        // Day: white, greyer as they thicken; night: dim blue-grey against the dark sky.
        let d = CGFloat(min(max(darkness, 0), 1))
        let color = SKColor(red: 0.96 - 0.68 * d, green: 0.97 - 0.66 * d, blue: 0.99 - 0.6 * d, alpha: 1)
        for (i, s) in sprites.enumerated() {
            guard i < clouds.count else { s.isHidden = true; continue }
            let c = clouds[i]
            s.isHidden = false
            s.position = CGPoint(x: c.center.x, y: c.center.y)
            s.size = CGSize(width: c.size.x, height: c.size.y)
            s.color = color
            s.alpha = CGFloat(c.opacity) * (1 - 0.4 * d)
        }
    }

    /// A soft cloud: overlapping radial blobs, flatter at the bottom.
    private static func puff() -> SKTexture {
        let w = 256, h = 96
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: [CGColor(red: 1, green: 1, blue: 1, alpha: 0.9), CGColor(red: 1, green: 1, blue: 1, alpha: 0)] as CFArray,
                                        locations: [0, 1]) else { return SKTexture() }
        let blobs: [(CGFloat, CGFloat, CGFloat)] = [(0.22, 0.38, 0.2), (0.4, 0.5, 0.27), (0.6, 0.46, 0.25), (0.78, 0.36, 0.19), (0.5, 0.3, 0.3)]
        for (x, y, r) in blobs {
            let center = CGPoint(x: x * CGFloat(w), y: y * CGFloat(h))
            // Radii follow the height so no blob is cut off at the texture's edge.
            ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: r * CGFloat(h) * 1.3,
                                   options: [])
        }
        return ctx.makeImage().map { SKTexture(cgImage: $0) } ?? SKTexture()
    }
}
