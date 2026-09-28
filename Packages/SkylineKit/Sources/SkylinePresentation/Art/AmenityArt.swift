import Foundation
import SkylineCore

/// Wall and ceiling details of amenity rooms (0.22), keyed by appearance. The furniture
/// comes from content (`interiors.json`); this adds what belongs to the room itself.
enum AmenityArt {
    static func decorate(into d: inout Drawing, appearance: String, rect r: Rect, ceiling: Double,
                         finishes f: (wall: RGBA, floor: RGBA, ceiling: RGBA), palette p: ArtPalette) {
        switch appearance {
        case "shop":
            // Track spotlights and a display band along the back wall.
            RoomArt.lights(into: &d, r, y: ceiling, spacing: 1.5, width: 0.2, palette: p)
            d.fill(Rect(minX: r.minX, minY: ceiling - 0.45, maxX: r.maxX, maxY: ceiling - 0.38), RGBA(hex: 0xC99A3E), minDetail: 8)
        case "restaurant":
            // Wood wainscot with a rail, and a warm glow along the ceiling.
            d.fill(Rect(minX: r.minX, minY: r.minY + 0.08, maxX: r.maxX, maxY: r.minY + 1.05), f.floor.shaded(1.15), minDetail: 6)
            d.fill(Rect(minX: r.minX, minY: r.minY + 1.05, maxX: r.maxX, maxY: r.minY + 1.1), f.floor.shaded(0.8), minDetail: 10)
            d.verticalGradient(Rect(minX: r.minX, minY: ceiling - 0.8, maxX: r.maxX, maxY: ceiling),
                               top: RGBA(hex: 0xFFD9A0).withAlpha(0.3), bottom: RGBA(hex: 0xFFD9A0).withAlpha(0), minDetail: 8)
        case "fitness":
            RoomArt.lights(into: &d, r, y: ceiling, spacing: 1.6, width: 1.0, palette: p)
            d.fill(Rect(minX: r.minX, minY: r.minY + 2.45, maxX: r.maxX, maxY: r.minY + 2.55), RGBA(hex: 0x3FA7D6), minDetail: 8)
        case "cinema":
            // Acoustic panels and aisle lights.
            var x = r.minX + 0.6
            while x < r.maxX - 0.4 {
                d.fill(Rect(minX: x, minY: r.minY + 0.5, maxX: x + 0.9, maxY: ceiling - 0.3), f.wall.shaded(1.18), minDetail: 8)
                d.fill(Rect(minX: x + 0.2, minY: r.minY + 0.12, maxX: x + 0.3, maxY: r.minY + 0.16), RGBA(hex: 0xF4D35E), minDetail: 20)
                x += 1.3
            }
        case "theater":
            // Gilded rail and wall sconces.
            d.fill(Rect(minX: r.minX, minY: r.minY + 1.2, maxX: r.maxX, maxY: r.minY + 1.25), RGBA(hex: 0xB5935A), minDetail: 8)
            var x = r.minX + 1.2
            while x < r.maxX - 0.6 {
                d.fill(Rect(minX: x - 0.08, minY: r.minY + 2.1, maxX: x + 0.08, maxY: r.minY + 2.35), RGBA(hex: 0xB5935A), minDetail: 12)
                d.verticalGradient(Rect(minX: x - 0.5, minY: r.minY + 2.35, maxX: x + 0.5, maxY: r.minY + 3.0),
                                   top: RGBA(hex: 0xFFE2A8).withAlpha(0), bottom: RGBA(hex: 0xFFE2A8).withAlpha(0.35), minDetail: 10)
                x += 2.4
            }
        case "skyBar":
            // A neon line under the ceiling fading from teal to pink.
            d.horizontalGradient(Rect(minX: r.minX, minY: ceiling - 0.08, maxX: r.maxX, maxY: ceiling - 0.03),
                                 stops: [GradientStop(0, RGBA(hex: 0x3FD6CB)), GradientStop(1, RGBA(hex: 0xFF5FA2))], minDetail: 6)
            d.verticalGradient(Rect(minX: r.minX, minY: ceiling - 0.9, maxX: r.maxX, maxY: ceiling - 0.08),
                               top: RGBA(hex: 0x8F7CFF).withAlpha(0.22), bottom: RGBA(hex: 0x8F7CFF).withAlpha(0), minDetail: 8)
        default:
            break
        }
    }
}
