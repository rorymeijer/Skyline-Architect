import Foundation
import QuartzCore
import SpriteKit
import SkylineCore
import SkylinePresentation

/// Shows the static composition as quadtree raster tiles (DECISIONS D-003).
///
/// Each frame `update` plans the tiles needed for the view, schedules missing or stale
/// ones on a background queue (bounded in-flight count), keeps other levels visible as
/// fallback until the wanted level is complete, and evicts least-recently-used textures.
/// When construction changes the composition, `replace(composition:dirty:)` marks the
/// affected tiles stale: they stay visible until their re-rendered replacement arrives,
/// so edits never flash empty tiles. All SpriteKit mutation happens on the main thread.
final class TileLayer {
    let node = SKNode()
    private var composition: SiteComposition
    private var planner: TileSetPlanner
    private var sprites: [TileKey: SKSpriteNode] = [:]
    private var emptyKeys = Set<TileKey>()
    private var staleKeys = Set<TileKey>()
    private var pending = Set<TileKey>()
    /// Incremented on every composition change; results of older jobs are discarded.
    private var generation = 0
    private let queue = DispatchQueue(label: "skyline.tiles", qos: .userInitiated, attributes: .concurrent)
    private let maxInFlight = 4
    /// Which layers of the composition this tile layer shows (Phase 12: the emission layer
    /// gets its own additive tile layer).
    private let select: @Sendable (SiteComposition) -> [CompositionLayer]
    private let blendMode: SKBlendMode

    // Diagnostics.
    private(set) var lastPlan = TilePlan(level: 0, wanted: [])
    private(set) var visibleCount = 0
    private(set) var rasterizedCount = 0
    private(set) var averageRasterMs = 0.0

    var pendingCount: Int { pending.count }
    var cachedCount: Int { sprites.count }
    /// True when every wanted tile of the current plan is displayed, current (not stale),
    /// or known to be empty.
    private(set) var isComplete = false

    init(composition: SiteComposition, pyramid: TilePyramid = TilePyramid(), budget: Int = 96,
         blendMode: SKBlendMode = .alpha, select: @escaping @Sendable (SiteComposition) -> [CompositionLayer] = { $0.layers }) {
        self.composition = composition
        self.select = select
        self.blendMode = blendMode
        planner = TileSetPlanner(pyramid: pyramid, budget: budget)
    }

    /// Switches to a new composition. Only tiles intersecting `dirty` are re-rendered;
    /// pass nil to invalidate everything.
    func replace(composition: SiteComposition, dirty: Rect?) {
        self.composition = composition
        generation += 1
        pending.removeAll()  // in-flight results are now obsolete (generation check)
        let wanted = Set(lastPlan.wanted)
        let pyramid = planner.pyramid
        func affected(_ key: TileKey) -> Bool { dirty.map { pyramid.rect(for: key).intersects($0) } ?? true }
        for key in sprites.keys where affected(key) {
            if wanted.contains(key) {
                staleKeys.insert(key)
            } else {
                sprites.removeValue(forKey: key)?.removeFromParent()
                planner.remove(key)
            }
        }
        emptyKeys = emptyKeys.filter { !affected($0) }
    }

    /// Swaps in a new composition whose shown layers did not change (no tile is redrawn).
    func retain(composition: SiteComposition) { self.composition = composition }

    func update(visible: Rect, zoom: Double, backingScale: Double) {
        let plan = planner.plan(visible: visible, screenPixelsPerMeter: zoom * backingScale, content: composition.extent)
        lastPlan = plan
        let wanted = Set(plan.wanted)

        for key in plan.wanted where (sprites[key] == nil || staleKeys.contains(key)) && !emptyKeys.contains(key) && !pending.contains(key) {
            guard pending.count < maxInFlight else { break }
            schedule(key)
        }

        isComplete = plan.wanted.allSatisfy { (sprites[$0] != nil && !staleKeys.contains($0)) || emptyKeys.contains($0) }
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
            staleKeys.remove(key)
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
        let layers = select(composition)
        let generation = self.generation
        queue.async { [weak self] in
            let start = CACurrentMediaTime()
            let image = DrawingRasterizer.rasterize(composition, layers: layers, rect: rect, pixelsPerMeter: ppm, tilePixels: pyramid.tilePixels)
            let ms = (CACurrentMediaTime() - start) * 1000
            DispatchQueue.main.async {
                self?.finish(key, rect: rect, image: image, ms: ms, generation: generation)
            }
        }
    }

    private func finish(_ key: TileKey, rect: Rect, image: CGImage?, ms: Double, generation: Int) {
        guard generation == self.generation else { return }  // composition changed meanwhile
        pending.remove(key)
        staleKeys.remove(key)
        rasterizedCount += 1
        averageRasterMs += (ms - averageRasterMs) / Double(min(rasterizedCount, 30))
        guard let image else {
            sprites.removeValue(forKey: key)?.removeFromParent()
            planner.remove(key)
            emptyKeys.insert(key)
            return
        }
        let full = SKTexture(cgImage: image)
        full.filteringMode = .linear
        // Crop the 1 px bleed border (see DrawingRasterizer).
        let inset = 1.0 / Double(image.width)
        let texture = SKTexture(rect: CGRect(x: inset, y: inset, width: 1 - 2 * inset, height: 1 - 2 * inset), in: full)
        texture.filteringMode = .linear
        if let existing = sprites[key] {
            existing.texture = texture
            return
        }
        let sprite = SKSpriteNode(texture: texture)
        sprite.blendMode = blendMode
        sprite.anchorPoint = .zero
        sprite.position = CGPoint(x: rect.minX, y: rect.minY)
        sprite.size = CGSize(width: rect.width, height: rect.height)
        sprite.isHidden = true
        node.addChild(sprite)
        sprites[key] = sprite
        planner.insert(key)
    }
}
