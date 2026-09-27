import Foundation
import SkylineCore

/// Colour decisions for the realistic/architectural art direction (GRAPHICS.md).
/// Centralised so a future day/night or weather grade can transform one palette.
public struct ArtPalette: Sendable {
    // Sky (world-anchored: horizon at grade → zenith high above).
    public var skyHorizon = RGBA(hex: 0xDCE4EA)
    public var skyLow = RGBA(hex: 0xAFC6DA)
    public var skyZenith = RGBA(hex: 0x6D93BE)

    // Distant city.
    public var backdropFar = RGBA(hex: 0xB4C2CF)
    public var backdropNear = RGBA(hex: 0x9CADBD)
    public var backdropFloorBand = RGBA(hex: 0xC3CEDA, alpha: 0.55)

    // Neighbouring buildings (mid-ground, muted).
    public var neighborMasonry = RGBA(hex: 0x9C8D80)
    public var neighborStone = RGBA(hex: 0xB9B3A8)
    public var neighborGlass = RGBA(hex: 0x7F95A6)
    public var neighborWindow = RGBA(hex: 0x5E6F7C)
    public var neighborMullion = RGBA(hex: 0xA7B1B8)

    // Ground.
    public var pavingTop = RGBA(hex: 0xC9C5BD)
    public var joint = RGBA(hex: 0x6F6B64)

    public func soil(_ m: SoilMaterial) -> RGBA {
        switch m {
        case .paving: RGBA(hex: 0xABA79F)
        case .topsoil: RGBA(hex: 0x4F3D2C)
        case .clay: RGBA(hex: 0x7C5F45)
        case .sand: RGBA(hex: 0xA58D66)
        case .gravel: RGBA(hex: 0x787161)
        case .bedrock: RGBA(hex: 0x5D5E62)
        }
    }

    // Concrete & steel.
    public var concreteCut = RGBA(hex: 0xB8B5AE)      // elements cut by the section plane
    public var concreteSurface = RGBA(hex: 0x8E8B85)  // surfaces seen beyond the cut (back walls)
    public var concreteEdge = RGBA(hex: 0x5F5C57)
    public var concreteHighlight = RGBA(hex: 0xD6D3CC)
    public var rebar = RGBA(hex: 0x8A5237)
    public var surveyStake = RGBA(hex: 0xB8966A)
    public var surveyCap = RGBA(hex: 0xE2702A)

    // Overlays.
    public var gridModule = RGBA(hex: 0x5BC8F0, alpha: 0.16)
    public var gridBay = RGBA(hex: 0x5BC8F0, alpha: 0.34)
    public var gridFloor = RGBA(hex: 0x5BC8F0, alpha: 0.26)
    public var gridFloorMajor = RGBA(hex: 0x5BC8F0, alpha: 0.5)
    public var gridGrade = RGBA(hex: 0x8FE0FF, alpha: 0.8)
    public var plotBoundary = RGBA(hex: 0xF08A3C, alpha: 0.85)
    public var hoverCell = RGBA(hex: 0x8FE0FF, alpha: 0.22)
    public var gridLabel = RGBA(hex: 0xDFF4FF, alpha: 0.9)

    public init() {}

    public static let standard = ArtPalette()
}
