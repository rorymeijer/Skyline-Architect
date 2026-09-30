import Foundation
import SkylineCore

/// Colour decisions for the realistic/architectural art direction (GRAPHICS.md).
/// Centralised so a future day/night or weather grade can transform one palette.
public struct ArtPalette: Sendable {
    /// Elevator hoistways drawn as glass (0.30, a view setting): the room behind shows through.
    public var seeThroughShafts = false

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

    // Building shell and finishes.
    public var shellWall = RGBA(hex: 0x9A978F)
    public var facadePanel = RGBA(hex: 0x7C8288)
    public var glazing = RGBA(hex: 0x9CC3D8)
    public var facadeGlass = RGBA(hex: 0x5F7C92)
    public var mullion = RGBA(hex: 0x4F555B)
    public var partition = RGBA(hex: 0xE9E6DF)
    public var door = RGBA(hex: 0x6B5A48)
    public var doorFrame = RGBA(hex: 0x3F4347)
    public var ceilingLight = RGBA(hex: 0xFFF6DD)
    public var roofMembrane = RGBA(hex: 0x3B3D40)
    public var steel = RGBA(hex: 0xA9B0B6)

    /// Wall, floor-finish and ceiling colours per room appearance key.
    public func finishes(_ appearance: String) -> (wall: RGBA, floor: RGBA, ceiling: RGBA) {
        switch appearance {
        case "office": (RGBA(hex: 0xD8DCDF), RGBA(hex: 0x5E6873), RGBA(hex: 0xEEF0F1))
        case "apartment": (RGBA(hex: 0xE3D7C2), RGBA(hex: 0x98734C), RGBA(hex: 0xF4F1EA))
        case "lobby": (RGBA(hex: 0xCFC7B9), RGBA(hex: 0xB9B3A8), RGBA(hex: 0xF1EEE7))
        case "corridor": (RGBA(hex: 0xC9CAC5), RGBA(hex: 0x8C8F8C), RGBA(hex: 0xE7E8E5))
        case "mechanical": (RGBA(hex: 0xA9ACAD), RGBA(hex: 0x7D8182), RGBA(hex: 0xB7BABB))
        case "electrical": (RGBA(hex: 0xB9B7A6), RGBA(hex: 0x807D6E), RGBA(hex: 0xC4C2B2))
        case "telecom": (RGBA(hex: 0x9FA8B3), RGBA(hex: 0x6E7782), RGBA(hex: 0xAEB6C0))
        case "fireControl": (RGBA(hex: 0xC9B8AE), RGBA(hex: 0x7A6A62), RGBA(hex: 0xD8CEC8))
        case "parking": (RGBA(hex: 0x9D9B95), RGBA(hex: 0x5C5D5E), RGBA(hex: 0xA7A59F))
        case "shop": (RGBA(hex: 0xECE5D8), RGBA(hex: 0xC8B597), RGBA(hex: 0xF7F4EE))
        case "restaurant": (RGBA(hex: 0xC9A17A), RGBA(hex: 0x6E4A2E), RGBA(hex: 0xEFE5D8))
        case "fitness": (RGBA(hex: 0xD6DEE3), RGBA(hex: 0x3A3D40), RGBA(hex: 0xF1F3F4))
        case "cinema": (RGBA(hex: 0x2F2B3B), RGBA(hex: 0x3B2F40), RGBA(hex: 0x1E1B26))
        case "theater": (RGBA(hex: 0x5C2029), RGBA(hex: 0x6B4A30), RGBA(hex: 0x2A1A1E))
        case "skyBar": (RGBA(hex: 0x2B303B), RGBA(hex: 0x4A3A30), RGBA(hex: 0x1F2229))
        case "waste": (RGBA(hex: 0xA9ADA6), RGBA(hex: 0x6F726C), RGBA(hex: 0xB9BCB5))
        case "staffRoom": (RGBA(hex: 0xDAD6CC), RGBA(hex: 0x8A7F70), RGBA(hex: 0xEFECE6))
        case "stairs": (RGBA(hex: 0x86847E), RGBA(hex: 0x6F6D68), RGBA(hex: 0x86847E))
        case "elevatorShaft": (RGBA(hex: 0x44484B), RGBA(hex: 0x303336), RGBA(hex: 0x44484B))
        case "expressElevatorShaft": (RGBA(hex: 0x3A4450), RGBA(hex: 0x2A3038), RGBA(hex: 0x3A4450))
        default: (RGBA(hex: 0xC8C8C8), RGBA(hex: 0x888888), RGBA(hex: 0xDDDDDD))
        }
    }

    // Overlays.
    public var gridModule = RGBA(hex: 0x5BC8F0, alpha: 0.16)
    public var gridBay = RGBA(hex: 0x5BC8F0, alpha: 0.34)
    public var gridFloor = RGBA(hex: 0x5BC8F0, alpha: 0.26)
    public var gridFloorMajor = RGBA(hex: 0x5BC8F0, alpha: 0.5)
    public var gridGrade = RGBA(hex: 0x8FE0FF, alpha: 0.8)
    public var plotBoundary = RGBA(hex: 0xF08A3C, alpha: 0.85)
    public var hoverCell = RGBA(hex: 0x8FE0FF, alpha: 0.22)
    public var gridLabel = RGBA(hex: 0xDFF4FF, alpha: 0.9)
    public var previewValid = RGBA(hex: 0x5FE39A, alpha: 0.28)
    public var previewValidEdge = RGBA(hex: 0x7CF2B0, alpha: 0.95)
    public var previewInvalid = RGBA(hex: 0xF0625A, alpha: 0.28)
    public var previewInvalidEdge = RGBA(hex: 0xFF7A70, alpha: 0.95)
    public var previewDemolish = RGBA(hex: 0xF0A23C, alpha: 0.3)

    public init() {}

    public static let standard = ArtPalette()
}
