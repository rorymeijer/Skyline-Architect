import CoreGraphics
import SpriteKit
import SkylineCore
import SkylinePresentation

/// Weather effects (Phase 13): rain or snow particles and a lightning flash in screen
/// space, a fog veil over the world, snow on roofs and pavement and wet paving in world
/// space. A pure view of `WeatherLook` data; particles are decoration (real time).
final class WeatherLayer {
    /// Scene children (screen space).
    let rain = SKEmitterNode()
    let snow = SKEmitterNode()
    let fog = SKSpriteNode(color: .white, size: .zero)
    let flash = SKSpriteNode(color: .white, size: .zero)
    /// World child: snow cover and wet paving.
    let ground = SKNode()
    private var roofSprites: [SKSpriteNode] = []
    private var streetSprites: [(snow: SKSpriteNode, wet: SKSpriteNode)] = []
    private var lastViewport = CGSize.zero
    private var raining = false, snowing = false

    init() {
        configure(rain, texture: Self.streak(), lifetime: 1.1, speed: 1150, angle: -.pi / 2 - 0.12, alpha: 0.32, scale: 1)
        rain.particleRotation = -0.12
        configure(snow, texture: Self.flake(), lifetime: 14, speed: 55, angle: -.pi / 2, alpha: 0.85, scale: 0.75)
        snow.particleSpeedRange = 30
        snow.xAcceleration = 4
        snow.particleScaleRange = 0.35
        snow.emissionAngleRange = 0.5
        for node in [fog, flash] { node.anchorPoint = .zero; node.isHidden = true }
        flash.blendMode = .add
    }

    private func configure(_ e: SKEmitterNode, texture: SKTexture, lifetime: CGFloat, speed: CGFloat, angle: CGFloat, alpha: CGFloat, scale: CGFloat) {
        e.particleTexture = texture
        e.particleBirthRate = 0
        e.particleLifetime = lifetime
        e.particleSpeed = speed
        e.particleSpeedRange = speed * 0.15
        e.emissionAngle = angle
        e.particleAlpha = alpha
        e.particleAlphaRange = alpha * 0.4
        e.particleScale = scale
        e.particleColor = .white
        e.particleColorBlendFactor = 1
        e.isHidden = true
    }

    func update(look: WeatherLook, darkness: Double, viewport: CGSize, roofs: [Rect], street: [ClosedRange<Double>]) {
        if viewport != lastViewport {
            lastViewport = viewport
            for e in [rain, snow] {
                e.position = CGPoint(x: viewport.width / 2, y: viewport.height + 30)
                e.particlePositionRange = CGVector(dx: viewport.width * 1.4, dy: 0)
            }
            snow.particleLifetime = viewport.height / 45 + 4
        }
        let isRain = look.precipitation == .rain && look.intensity > 0.01
        let isSnow = look.precipitation == .snow && look.intensity > 0.01
        rain.isHidden = !isRain
        rain.particleBirthRate = isRain ? CGFloat(180 + 520 * look.intensity) * viewport.width / 1024 : 0
        snow.isHidden = !isSnow
        snow.particleBirthRate = isSnow ? CGFloat(40 + 110 * look.intensity) * viewport.width / 1024 : 0
        // Prewarm when precipitation starts so the sky is already full.
        if isRain, !raining { rain.resetSimulation(); rain.advanceSimulationTime(1.5) }
        if isSnow, !snowing { snow.resetSimulation(); snow.advanceSimulationTime(Double(snow.particleLifetime)) }
        raining = isRain
        snowing = isSnow
        rain.particleColor = SKColor(white: 1 - 0.55 * darkness, alpha: 1)

        let dim = 1 - 0.75 * darkness
        fog.size = viewport
        fog.isHidden = look.fog < 0.01
        fog.color = SKColor(red: 0.80 * dim, green: 0.83 * dim, blue: 0.87 * dim, alpha: 1)
        fog.alpha = CGFloat(look.fog * 0.5)
        flash.size = viewport
        flash.isHidden = look.lightning < 0.01
        flash.alpha = CGFloat(look.lightning * 0.22)

        // Ground: snow lies on the street and on roofs; rain darkens the paving (never over
        // the cutaway building).
        while streetSprites.count < street.count {
            let snow = SKSpriteNode(color: SKColor(red: 0.95, green: 0.97, blue: 1, alpha: 1), size: .zero)
            let wet = SKSpriteNode(color: .black, size: .zero)
            for s in [wet, snow] { s.anchorPoint = .zero; ground.addChild(s) }
            streetSprites.append((snow, wet))
        }
        for (i, pair) in streetSprites.enumerated() {
            guard i < street.count else { pair.snow.isHidden = true; pair.wet.isHidden = true; continue }
            let x = street[i]
            pair.snow.isHidden = look.snowCover < 0.01
            pair.snow.position = CGPoint(x: x.lowerBound, y: -0.05)
            pair.snow.size = CGSize(width: x.upperBound - x.lowerBound, height: 0.5 * look.snowCover + 0.1)
            pair.wet.isHidden = look.wet < 0.01
            pair.wet.position = CGPoint(x: x.lowerBound, y: -0.3)
            pair.wet.size = CGSize(width: x.upperBound - x.lowerBound, height: 0.3)
            pair.wet.alpha = CGFloat(0.35 * look.wet)
        }
        while roofSprites.count < roofs.count {
            let s = SKSpriteNode(color: SKColor(red: 0.95, green: 0.97, blue: 1, alpha: 1), size: .zero)
            s.anchorPoint = .zero
            ground.addChild(s)
            roofSprites.append(s)
        }
        for (i, s) in roofSprites.enumerated() {
            guard i < roofs.count, look.snowCover > 0.01 else { s.isHidden = true; continue }
            let r = roofs[i]
            s.isHidden = false
            s.position = CGPoint(x: r.minX, y: r.minY)
            s.size = CGSize(width: r.width, height: r.height * look.snowCover)
        }
    }

    private static func streak() -> SKTexture {
        image(width: 2, height: 26) { ctx, w, h in
            for y in 0..<h {
                ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: CGFloat(y) / CGFloat(h))
                ctx.fill(CGRect(x: 0, y: y, width: w, height: 1))
            }
        }
    }

    private static func flake() -> SKTexture {
        image(width: 8, height: 8) { ctx, w, h in
            ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
            ctx.fillEllipse(in: CGRect(x: 1, y: 1, width: w - 2, height: h - 2))
        }
    }

    private static func image(width: Int, height: Int, draw: (CGContext, Int, Int) -> Void) -> SKTexture {
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return SKTexture()
        }
        draw(ctx, width, height)
        return ctx.makeImage().map { SKTexture(cgImage: $0) } ?? SKTexture()
    }
}
