import Foundation
import QuartzCore
import SpriteKit
import SkylineCore
import SkylinePresentation

/// Shows the static composition as quadtree raster tiles (DECISIONS D-003).
///
/// Each frame `update` plans the tiles needed for the view, schedules missing ones on a
/// background queue (bounded in-flight count), keeps coarser/finer tiles visible as
/// fallback until the wanted level is complete, and evicts least-recently-used textures.
/// All SpriteKit mutation happens on the main thread.
final class TileLayer {
    let node = SKNode()
    private let composition: SiteComposition
    private var planner: TileSetPlanner
    private var sprites: [TileKey: SKSpriteNode] = [:]
    private var emptyKeys = Set<TileKey>()
    private var pending = Set<TileKey>()
    private let queue = DispatchQueue(label: "skyline.tiles", qos: .userInitiated, attributes: .concurrent)
    private let maxInFlight = 4

    // Diagnostics.
    private(set) var lastPlan = TilePlan(level: 0, wanted: [])
    private(set) var visibleCount = 0
    private(set) var rasterizedCount = 0
    private(set) var averageRasterMs = 0.0

    var pendingCount: Int { pending.count }
    var cachedCount: Int { sprites.count }
    /// True when every wanted tile of the current plan is displayed (or known empty).
    private(set) var isComplete = false

    init(composition: SiteComposition, pyramid: TilePyramid = TilePyramid(), budget: Int = 96) {
        self.composition = composition
        planner = TileSetPlanner(pyramid: pyramid, budget: budget)
    }

    func update(visible: Rect, zoom: Double, backingScale: Double) {
        let plan = planner.plan(visible: visible, screenPixelsPerMeter: zoom * backingScale, content: composition.extent)
        lastPlan = plan
        let wanted = Set(plan.wanted)

        for key in plan.wanted where sprites[key] == nil && !emptyKeys.contains(key) && !pending.contains(key) {
            guard pending.count < maxInFlight else { break }
            schedule(key)
        }

        isComplete = plan.wanted.allSatisfy { sprites[$0] != nil || emptyKeys.contains($0) }
        var shown: [TileKey] = []
        for (key, sprite) in sprites {
            let isWanted = wanted.contains(key)
            // Until the wanted level is complete, other levels fill the gaps underneath.
            let show = isWanted || (!isComplete && planner.pyramid.rect(for: key).intersects(visible))
            sprite.isHidden = !show
            sprite.zPosition = isWanted ? 1 : 0
            if show { shown.append(key) }
        }
        visibleCount = shown.count
        planner.touch(shown)

        for key in planner.evictions(protecting: wanted) {
            sprites.removeValue(forKey: key)?.removeFromParent()
            planner.remove(key)
        }
        if emptyKeys.count > 8192 { emptyKeys.removeAll() }
    }

    private func schedule(_ key: TileKey) {
        pending.insert(key)
        let pyramid = planner.pyramid
        let rect = pyramid.rect(for: key)
        let ppm = pyramid.pixelsPerMeter(level: key.level)
        let composition = self.composition
        queue.async { [weak self] in
            let start = CACurrentMediaTime()
            let image = DrawingRasterizer.rasterize(composition, rect: rect, pixelsPerMeter: ppm, tilePixels: pyramid.tilePixels)
            let ms = (CACurrentMediaTime() - start) * 1000
            DispatchQueue.main.async {
                self?.finish(key, rect: rect, image: image, ms: ms)
            }
        }
    }

    private func finish(_ key: TileKey, rect: Rect, image: CGImage?, ms: Double) {
        pending.remove(key)
        guard let image else {
            emptyKeys.insert(key)
            return
        }
        rasterizedCount += 1
        averageRasterMs += (ms - averageRasterMs) / Double(min(rasterizedCount, 30))

        let full = SKTexture(cgImage: image)
        full.filteringMode = .linear
        // Crop the 1 px bleed border (see DrawingRasterizer).
        let inset = 1.0 / Double(image.width)
        let texture = SKTexture(rect: CGRect(x: inset, y: inset, width: 1 - 2 * inset, height: 1 - 2 * inset), in: full)
        texture.filteringMode = .linear
        let sprite = SKSpriteNode(texture: texture)
        sprite.anchorPoint = .zero
        sprite.position = CGPoint(x: rect.minX, y: rect.minY)
        sprite.size = CGSize(width: rect.width, height: rect.height)
        sprite.isHidden = true
        node.addChild(sprite)
        sprites[key] = sprite
        planner.insert(key)
    }
}
