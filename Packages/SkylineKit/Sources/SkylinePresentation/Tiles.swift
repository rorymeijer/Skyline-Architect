import Foundation
import SkylineCore

/// Address of a raster tile: quadtree level and integer tile coordinates.
public struct TileKey: Hashable, Comparable, Sendable, CustomStringConvertible {
    public var level: Int
    public var x: Int
    public var y: Int

    public init(level: Int, x: Int, y: Int) {
        self.level = level
        self.x = x
        self.y = y
    }

    public static func < (a: TileKey, b: TileKey) -> Bool {
        (a.level, a.y, a.x) < (b.level, b.y, b.x)
    }

    public var description: String { "L\(level)(\(x),\(y))" }
}

/// Tile geometry: level L rasterizes at `basePixelsPerMeter · 2^L`; every tile is
/// `tilePixels` square, so tiles cover less world area at higher levels.
public struct TilePyramid: Hashable, Sendable {
    public var tilePixels: Int
    public var basePixelsPerMeter: Double
    public var maxLevel: Int

    public init(tilePixels: Int = 512, basePixelsPerMeter: Double = 2, maxLevel: Int = 7) {
        self.tilePixels = tilePixels
        self.basePixelsPerMeter = basePixelsPerMeter
        self.maxLevel = maxLevel
    }

    public func pixelsPerMeter(level: Int) -> Double { basePixelsPerMeter * pow(2, Double(level)) }
    public func tileWorldSize(level: Int) -> Double { Double(tilePixels) / pixelsPerMeter(level: level) }

    /// Level whose density best matches `screenPixelsPerMeter` (zoom × backing scale).
    /// Allows up to ~20 % magnification before switching to a finer level.
    public func level(forScreenPixelsPerMeter p: Double) -> Int {
        guard p > basePixelsPerMeter else { return 0 }
        let exact = log2(p / basePixelsPerMeter)
        return min(maxLevel, max(0, Int((exact - 0.26).rounded(.up))))
    }

    public func rect(for key: TileKey) -> Rect {
        let s = tileWorldSize(level: key.level)
        return Rect(x: Double(key.x) * s, y: Double(key.y) * s, width: s, height: s)
    }

    /// Tiles at `level` covering `rect`, row-major from the bottom-left.
    public func keys(covering rect: Rect, level: Int) -> [TileKey] {
        guard !rect.isEmpty else { return [] }
        let s = tileWorldSize(level: level)
        let x0 = Int((rect.minX / s).rounded(.down)), x1 = Int((rect.maxX / s).rounded(.up)) - 1
        let y0 = Int((rect.minY / s).rounded(.down)), y1 = Int((rect.maxY / s).rounded(.up)) - 1
        guard x1 >= x0, y1 >= y0 else { return [] }
        var keys: [TileKey] = []
        keys.reserveCapacity((x1 - x0 + 1) * (y1 - y0 + 1))
        for y in y0...y1 { for x in x0...x1 { keys.append(TileKey(level: level, x: x, y: y)) } }
        return keys
    }
}

/// What the renderer should show for a view.
public struct TilePlan: Sendable, Equatable {
    public var level: Int
    /// Tiles that intersect content and the (slightly expanded) view, nearest-first.
    public var wanted: [TileKey]

    public init(level: Int, wanted: [TileKey]) {
        self.level = level
        self.wanted = wanted
    }
}

/// Plans tiles for a view and keeps LRU bookkeeping for the renderer's texture cache.
/// Pure logic: the renderer owns the textures, this decides which ones to keep.
public struct TileSetPlanner: Sendable {
    public let pyramid: TilePyramid
    /// Maximum number of cached tiles; wanted tiles are never evicted.
    public var budget: Int
    private var lastUsed: [TileKey: UInt64] = [:]
    private var clock: UInt64 = 0

    public init(pyramid: TilePyramid = TilePyramid(), budget: Int = 96) {
        self.pyramid = pyramid
        self.budget = budget
    }

    public var cachedCount: Int { lastUsed.count }

    /// Tiles needed to show `visible` at `screenPixelsPerMeter`, limited to `content`.
    /// `prefetch` expands the view by that fraction of its size on each side.
    public func plan(visible: Rect, screenPixelsPerMeter: Double, content: Rect, prefetch: Double = 0.1) -> TilePlan {
        let level = pyramid.level(forScreenPixelsPerMeter: screenPixelsPerMeter)
        let expanded = visible.insetBy(dx: -visible.width * prefetch, dy: -visible.height * prefetch)
        let area = expanded.intersection(content)
        let c = visible.center
        let keys = pyramid.keys(covering: area, level: level).sorted {
            let da = (pyramid.rect(for: $0).center - c).length, db = (pyramid.rect(for: $1).center - c).length
            return da == db ? $0 < $1 : da < db
        }
        return TilePlan(level: level, wanted: keys)
    }

    /// Marks tiles as used this frame (call with every displayed tile).
    public mutating func touch<S: Sequence>(_ keys: S) where S.Element == TileKey {
        clock += 1
        for k in keys { lastUsed[k] = clock }
    }

    public mutating func insert(_ key: TileKey) {
        clock += 1
        lastUsed[key] = clock
    }

    public mutating func remove(_ key: TileKey) { lastUsed[key] = nil }

    public mutating func removeAll() { lastUsed.removeAll() }

    /// Least-recently-used tiles to drop so the cache fits the budget. Deterministic order.
    public func evictions(protecting wanted: Set<TileKey>) -> [TileKey] {
        let excess = lastUsed.count - budget
        guard excess > 0 else { return [] }
        return lastUsed.filter { !wanted.contains($0.key) }
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value < $1.value }
            .prefix(excess).map(\.key)
    }
}
