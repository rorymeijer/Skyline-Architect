import Foundation

/// World-anchored sky gradient: stops are altitudes in meters above grade. Above the last
/// stop the zenith colour continues. Renderers stretch a 1-D gradient over these heights.
public struct SkyGradient: Sendable, Equatable {
    public var stops: [(altitude: Double, color: RGBA)]

    public static func == (a: SkyGradient, b: SkyGradient) -> Bool {
        a.stops.map(\.altitude) == b.stops.map(\.altitude) && a.stops.map(\.color) == b.stops.map(\.color)
    }

    public var top: Double { stops.last?.altitude ?? 0 }
    public var zenith: RGBA { stops.last?.color ?? .black }

    public static func day(_ p: ArtPalette) -> SkyGradient {
        SkyGradient(stops: [(0, p.skyHorizon), (160, p.skyLow), (900, p.skyZenith)])
    }

    /// Colour at `altitude` (piecewise linear).
    public func color(at altitude: Double) -> RGBA {
        guard let first = stops.first else { return .black }
        if altitude <= first.altitude { return first.color }
        for (a, b) in zip(stops, stops.dropFirst()) where altitude <= b.altitude {
            return a.color.mixed(with: b.color, (altitude - a.altitude) / (b.altitude - a.altitude))
        }
        return zenith
    }
}
