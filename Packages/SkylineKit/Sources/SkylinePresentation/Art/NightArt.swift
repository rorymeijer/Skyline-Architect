import Foundation
import SkylineCore

/// Static night lights of the site (Phase 12): windows of the city and the neighbours, and
/// street lamps. They form the composition's emission layer, which the renderer adds on
/// top of the graded scene with the current darkness as opacity.
enum NightArt {
    static let warm = RGBA(1.0, 0.80, 0.50)
    static let cool = RGBA(0.84, 0.90, 1.0)

    static func windowColor(_ rng: inout SeededRandom) -> RGBA {
        (rng.chance(0.7) ? warm : cool).withAlpha(rng.double(in: 0.55..<0.9))
    }

    /// Random lit windows on a distant building (reduced scale: 1.6 m floor bands).
    static func cityWindows(into d: inout Drawing, building r: Rect, share: Double, avoid: [Rect] = [], seed: UInt64) {
        var rng = SeededRandom(seed: seed, stream: 0x3317)
        var y = 1.8
        while y < r.maxY - 1 {
            var x = r.minX + 0.5
            while x + 0.8 < r.maxX - 0.4 {
                let window = Rect(minX: x, minY: y, maxX: x + 0.8, maxY: y + 0.55)
                if rng.chance(share), !avoid.contains(where: { $0.intersects(window) }) { d.fill(window, windowColor(&rng)) }
                x += 1.2
            }
            y += 1.6
        }
    }

    /// Lamp x positions: every 32 m across `span`, none within `keepClear` (the buildable
    /// frontage, where lamps would stand in front of the cutaway).
    static func lampPositions(span: ClosedRange<Double>, keepClear: ClosedRange<Double>) -> [Double] {
        var xs: [Double] = []
        var x = (span.lowerBound / 32).rounded(.up) * 32
        while x <= span.upperBound {
            if x < keepClear.lowerBound - 2 || x > keepClear.upperBound + 2 { xs.append(x) }
            x += 32
        }
        return xs
    }

    /// Posts (site layer, visible by day) and their glow (emission layer).
    static func streetLamps(site d: inout Drawing, lights: inout Drawing, at xs: [Double], palette p: ArtPalette) {
        let pole = RGBA(0.24, 0.26, 0.29)
        for x in xs {
            d.fill(Rect(minX: x - 0.08, minY: 0, maxX: x + 0.08, maxY: 6.2), pole)
            d.fill(Rect(minX: x - 0.08, minY: 6.05, maxX: x + 1.1, maxY: 6.2), pole)
            d.fill(Rect(minX: x + 0.55, minY: 5.85, maxX: x + 1.25, maxY: 6.05), pole.shaded(1.3))
            let head = Vec2(x + 0.9, 5.9)
            lights.ellipse(Rect(minX: head.x - 4, minY: head.y - 4, maxX: head.x + 4, maxY: head.y + 4), warm.withAlpha(0.10))
            lights.ellipse(Rect(minX: head.x - 1.6, minY: head.y - 1.6, maxX: head.x + 1.6, maxY: head.y + 1.6), warm.withAlpha(0.22))
            lights.ellipse(Rect(minX: head.x - 0.45, minY: head.y - 0.3, maxX: head.x + 0.45, maxY: head.y + 0.2), RGBA(1, 0.95, 0.8, 0.95))
            // Pool of light on the pavement.
            lights.ellipse(Rect(minX: head.x - 3.5, minY: -0.35, maxX: head.x + 3.5, maxY: 0.35), warm.withAlpha(0.35))
        }
    }
}
