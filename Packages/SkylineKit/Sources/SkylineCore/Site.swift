import Foundation

/// Ground material of a soil stratum. String-backed so content files stay readable.
/// Visual appearance is decided by the presentation layer, not here.
public enum SoilMaterial: String, Codable, Sendable, CaseIterable {
    case paving, topsoil, clay, sand, gravel, bedrock
}

/// One horizontal layer of ground, listed top-down beneath grade.
public struct SoilStratum: Codable, Hashable, Sendable {
    public var material: SoilMaterial
    /// Thickness in meters. The last stratum of a profile is treated as unbounded.
    public var thickness: Double

    public init(material: SoilMaterial, thickness: Double) {
        self.material = material
        self.thickness = thickness
    }
}

/// A soil stratum placed at absolute depths (y values, negative below grade).
public struct PlacedStratum: Hashable, Sendable {
    public var material: SoilMaterial
    public var topY: Double
    /// `-infinity` for the bottom (bedrock) stratum.
    public var bottomY: Double
}

/// The land of a property: which columns may be built on and what lies beneath.
public struct Plot: Codable, Hashable, Sendable {
    /// Buildable columns in property-local coordinates.
    public var frontage: ColumnSpan
    /// Maximum number of basement floors permitted (zoning / geology).
    public var maxBasementFloors: Int
    /// Columns of neighbouring context rendered on each side of the frontage (not buildable).
    public var siteMargin: Int
    /// Ground profile, top-down. Must contain at least one stratum.
    public var strata: [SoilStratum]

    public init(frontage: ColumnSpan, maxBasementFloors: Int, siteMargin: Int, strata: [SoilStratum]) {
        precondition(!strata.isEmpty, "A plot needs at least one soil stratum")
        self.frontage = frontage
        self.maxBasementFloors = maxBasementFloors
        self.siteMargin = siteMargin
        self.strata = strata
    }

    /// Frontage plus margins: the columns shown as the property's site.
    public var siteColumns: ColumnSpan {
        ColumnSpan(start: frontage.start - siteMargin, count: frontage.count + 2 * siteMargin)
    }

    /// Strata positioned by depth. The last one extends to `-infinity`.
    public var placedStrata: [PlacedStratum] {
        var top = 0.0
        return strata.enumerated().map { i, s in
            let bottom = i == strata.count - 1 ? -Double.infinity : top - s.thickness
            defer { top = bottom }
            return PlacedStratum(material: s.material, topY: top, bottomY: bottom)
        }
    }

    /// Depth (positive meters) at which the bottom stratum begins.
    public var bedrockDepth: Double {
        strata.dropLast().reduce(0) { $0 + $1.thickness }
    }
}
