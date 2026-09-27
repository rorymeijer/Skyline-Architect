import Foundation

/// Linear-agnostic sRGB color with straight (non-premultiplied) alpha, 0…1 components.
public struct RGBA: Hashable, Codable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double
    public var a: Double

    public init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    /// `RGBA(hex: 0xA7A49D)`.
    public init(hex: UInt32, alpha: Double = 1) {
        self.init(
            Double((hex >> 16) & 0xFF) / 255,
            Double((hex >> 8) & 0xFF) / 255,
            Double(hex & 0xFF) / 255,
            alpha)
    }

    public func withAlpha(_ a: Double) -> RGBA { RGBA(r, g, b, a) }

    /// Linear interpolation towards `other` (t = 0 → self, 1 → other).
    public func mixed(with other: RGBA, _ t: Double) -> RGBA {
        RGBA(r + (other.r - r) * t, g + (other.g - g) * t, b + (other.b - b) * t, a + (other.a - a) * t)
    }

    /// Multiplies RGB by `factor` (< 1 darkens, > 1 lightens), clamped.
    public func shaded(_ factor: Double) -> RGBA {
        RGBA(min(1, r * factor), min(1, g * factor), min(1, b * factor), a)
    }

    public static let black = RGBA(0, 0, 0)
    public static let white = RGBA(1, 1, 1)
    public static let clear = RGBA(0, 0, 0, 0)
}
