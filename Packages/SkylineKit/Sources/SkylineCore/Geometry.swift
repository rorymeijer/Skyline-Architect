import Foundation

/// A 2D vector / point in world meters (x right, y up). Platform-neutral replacement for
/// CGPoint so the model never depends on CoreGraphics (DECISIONS D-002).
public struct Vec2: Hashable, Codable, Sendable, CustomStringConvertible {
    public var x: Double
    public var y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = Vec2(0, 0)

    public var length: Double { (x * x + y * y).squareRoot() }

    public static func + (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x + b.x, a.y + b.y) }
    public static func - (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x - b.x, a.y - b.y) }
    public static func * (a: Vec2, s: Double) -> Vec2 { Vec2(a.x * s, a.y * s) }
    public static func / (a: Vec2, s: Double) -> Vec2 { Vec2(a.x / s, a.y / s) }
    public static prefix func - (a: Vec2) -> Vec2 { Vec2(-a.x, -a.y) }
    public static func += (a: inout Vec2, b: Vec2) { a = a + b }
    public static func -= (a: inout Vec2, b: Vec2) { a = a - b }

    public var description: String { "(\(x), \(y))" }
}

/// Axis-aligned rectangle defined by its edges. Empty when max < min on either axis.
public struct Rect: Hashable, Codable, Sendable, CustomStringConvertible {
    public var minX: Double
    public var minY: Double
    public var maxX: Double
    public var maxY: Double

    public init(minX: Double, minY: Double, maxX: Double, maxY: Double) {
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.init(minX: x, minY: y, maxX: x + width, maxY: y + height)
    }

    public init(center: Vec2, size: Vec2) {
        self.init(
            minX: center.x - size.x / 2, minY: center.y - size.y / 2,
            maxX: center.x + size.x / 2, maxY: center.y + size.y / 2)
    }

    /// Smallest rect containing all points. Returns `.null` for an empty sequence.
    public init<S: Sequence>(bounding points: S) where S.Element == Vec2 {
        var r = Rect.null
        for p in points { r = r.union(Rect(minX: p.x, minY: p.y, maxX: p.x, maxY: p.y)) }
        self = r
    }

    /// The identity for `union`: an inverted infinite rect.
    public static let null = Rect(
        minX: .infinity, minY: .infinity, maxX: -.infinity, maxY: -.infinity)

    public var width: Double { maxX - minX }
    public var height: Double { maxY - minY }
    public var size: Vec2 { Vec2(width, height) }
    public var center: Vec2 { Vec2((minX + maxX) / 2, (minY + maxY) / 2) }
    public var isEmpty: Bool { !(maxX > minX && maxY > minY) }
    public var isNull: Bool { minX > maxX || minY > maxY }

    public func contains(_ p: Vec2) -> Bool {
        p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY
    }

    public func contains(_ r: Rect) -> Bool {
        r.minX >= minX && r.maxX <= maxX && r.minY >= minY && r.maxY <= maxY
    }

    /// True when the interiors overlap (touching edges do not count).
    public func intersects(_ r: Rect) -> Bool {
        minX < r.maxX && r.minX < maxX && minY < r.maxY && r.minY < maxY
    }

    public func intersection(_ r: Rect) -> Rect {
        Rect(minX: max(minX, r.minX), minY: max(minY, r.minY),
             maxX: min(maxX, r.maxX), maxY: min(maxY, r.maxY))
    }

    public func union(_ r: Rect) -> Rect {
        Rect(minX: min(minX, r.minX), minY: min(minY, r.minY),
             maxX: max(maxX, r.maxX), maxY: max(maxY, r.maxY))
    }

    public func insetBy(dx: Double, dy: Double) -> Rect {
        Rect(minX: minX + dx, minY: minY + dy, maxX: maxX - dx, maxY: maxY - dy)
    }

    public var description: String { "Rect(x: \(minX)…\(maxX), y: \(minY)…\(maxY))" }
}
