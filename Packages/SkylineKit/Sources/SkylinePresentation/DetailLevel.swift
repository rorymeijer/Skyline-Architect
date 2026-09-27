import Foundation

/// Level-of-detail band chosen from zoom (points per meter). Later phases decide per band
/// what to render (façade vs. interiors, agent dots vs. sprites); see GRAPHICS.md.
public enum DetailLevel: Int, CaseIterable, Comparable, Sendable, CustomStringConvertible {
    case skyline, massing, floors, rooms, interior

    /// Lower zoom bound of each band (points per meter).
    public static let thresholds: [Double] = [0, 1.5, 5, 14, 40]

    public var lowerBound: Double { Self.thresholds[rawValue] }

    public static func < (a: DetailLevel, b: DetailLevel) -> Bool { a.rawValue < b.rawValue }

    public var description: String {
        switch self {
        case .skyline: "Skyline"
        case .massing: "Massing"
        case .floors: "Floors"
        case .rooms: "Rooms"
        case .interior: "Interior"
        }
    }
}

/// Picks detail levels with hysteresis so the level does not flicker when the zoom hovers
/// around a threshold.
public struct DetailLevelPolicy: Sendable {
    /// Fractional margin around thresholds (0.1 = must pass threshold by 10 %).
    public var hysteresis: Double

    public init(hysteresis: Double = 0.1) { self.hysteresis = hysteresis }

    public func level(forZoom zoom: Double, current: DetailLevel?) -> DetailLevel {
        guard var level = current else {
            return DetailLevel.allCases.last { zoom >= $0.lowerBound } ?? .skyline
        }
        while let next = DetailLevel(rawValue: level.rawValue + 1), zoom >= next.lowerBound * (1 + hysteresis) {
            level = next
        }
        while level.rawValue > 0, zoom < level.lowerBound * (1 - hysteresis) {
            level = DetailLevel(rawValue: level.rawValue - 1)!
        }
        return level
    }
}
