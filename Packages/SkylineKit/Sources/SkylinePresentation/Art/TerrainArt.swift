import Foundation
import SkylineCore

/// Ground cross-section: strata with undulating interfaces, material grain, paving at
/// grade and depth darkening. Deterministic for a given seed.
enum TerrainArt {
    /// - Parameters:
    ///   - extent: full horizontal/vertical region to cover (y from bottom to 0).
    ///   - detailSpan: x-range where grain and wavy interfaces are generated (the site).
    static func draw(into d: inout Drawing, plot: Plot, extent: Rect, detailSpan: ClosedRange<Double>,
                     palette p: ArtPalette, seed: UInt64) {
        var rng = SeededRandom(seed: seed, stream: 0x7E44)
        let strata = plot.placedStrata

        // 1. Strata bodies, top to bottom. Each polygon runs from its (wavy) top interface
        //    to the extent bottom; the next stratum paints over the lower part.
        for (i, s) in strata.enumerated() {
            let top = interface(y: s.topY, wavy: i > 1, extent: extent, detailSpan: detailSpan, rng: &rng)
            let color = p.soil(s.material)
            var pts = top
            pts.append(Vec2(extent.maxX, extent.minY))
            pts.append(Vec2(extent.minX, extent.minY))
            d.add(DrawItem(shape: .polygon(pts), fill: .linear(
                start: Vec2(0, s.topY), end: Vec2(0, max(s.bottomY, extent.minY)),
                stops: [GradientStop(0, color.shaded(1.06)), GradientStop(1, color.shaded(0.9))])))
        }

        // 2. Grain within the site only (items carry detail thresholds).
        for s in strata where s.material != .paving {
            let band = Rect(minX: detailSpan.lowerBound, minY: max(s.bottomY, extent.minY),
                            maxX: detailSpan.upperBound, maxY: s.topY)
            grain(into: &d, material: s.material, band: band, palette: p, rng: &rng)
        }

        // 3. Paving at grade: top highlight + expansion joints.
        if let paving = strata.first, paving.material == .paving {
            d.fill(Rect(minX: extent.minX, minY: -0.06, maxX: extent.maxX, maxY: 0), p.pavingTop)
            var x = (detailSpan.lowerBound / 3).rounded(.down) * 3
            while x <= detailSpan.upperBound {
                d.fill(Rect(minX: x, minY: paving.bottomY, maxX: x + 0.02, maxY: 0), p.joint.withAlpha(0.6), minDetail: 12)
                x += 3
            }
        }

        // 4. Depth darkening over everything below grade.
        d.verticalGradient(Rect(minX: extent.minX, minY: extent.minY, maxX: extent.maxX, maxY: 0),
                           top: RGBA(0, 0, 0, 0), bottom: RGBA(0.02, 0.02, 0.03, 0.45))
    }

    /// Interface line at `y`, undulating inside the detail span, straight outside.
    private static func interface(y: Double, wavy: Bool, extent: Rect, detailSpan: ClosedRange<Double>,
                                  rng: inout SeededRandom) -> [Vec2] {
        var pts = [Vec2(extent.minX, y)]
        if wavy {
            var x = detailSpan.lowerBound
            var phase = rng.double(in: 0..<(2 * .pi))
            while x <= detailSpan.upperBound {
                // Fade the undulation to zero at the span ends so it meets the straight part.
                let edge = min(x - detailSpan.lowerBound, detailSpan.upperBound - x)
                let fade = min(1, edge / 12)
                phase += rng.double(in: 0.25..<0.6)
                pts.append(Vec2(x, y + fade * (sin(phase) * 0.35 + rng.double(in: -0.08..<0.08))))
                x += 2
            }
        }
        pts.append(Vec2(extent.maxX, y))
        return pts
    }

    private static func grain(into d: inout Drawing, material: SoilMaterial, band: Rect,
                              palette p: ArtPalette, rng: inout SeededRandom) {
        guard !band.isEmpty else { return }
        let base = p.soil(material)
        let area = band.width * band.height
        func point() -> Vec2 { Vec2(rng.double(in: band.minX..<band.maxX), rng.double(in: band.minY..<band.maxY)) }
        func dot(_ c: Vec2, _ r: Double, _ color: RGBA, _ detail: Double) {
            d.ellipse(Rect(center: c, size: Vec2(r * 2, r * 1.7)), color, minDetail: detail)
        }
        switch material {
        case .topsoil:
            for _ in 0..<Int(area * 2.5) {
                dot(point(), rng.double(in: 0.03..<0.07), base.shaded(rng.double(in: 0.55..<0.8)), 28)
            }
            for _ in 0..<Int(area * 0.25) {
                // Fine roots: short dark hairlines.
                let a = point()
                d.line([a, a + Vec2(rng.double(in: -0.3..<0.3), -rng.double(in: 0.1..<0.4))],
                       base.shaded(0.5).withAlpha(0.7), width: 0.015, minDetail: 40)
            }
        case .clay:
            for _ in 0..<Int(area * 0.12) {
                // Lighter silt lenses.
                let c = point(), w = rng.double(in: 0.6..<2.2)
                d.ellipse(Rect(center: c, size: Vec2(w, rng.double(in: 0.05..<0.12))),
                          base.shaded(1.18).withAlpha(0.55), minDetail: 10)
            }
            for _ in 0..<Int(area * 1.2) {
                dot(point(), rng.double(in: 0.02..<0.05), base.shaded(rng.double(in: 0.8..<1.2)).withAlpha(0.8), 36)
            }
        case .sand:
            for _ in 0..<Int(area * 3) {
                let light = rng.chance(0.5)
                dot(point(), rng.double(in: 0.015..<0.035), base.shaded(light ? 1.22 : 0.78).withAlpha(0.8), 48)
            }
            for _ in 0..<Int(area * 0.1) {
                // Cross-bedding: faint diagonal laminae.
                let a = point(), len = rng.double(in: 0.8..<1.8)
                d.line([a, a + Vec2(len, -len * 0.25)], base.shaded(0.85).withAlpha(0.5), width: 0.025, minDetail: 14)
            }
        case .gravel:
            for _ in 0..<Int(area * 3) {
                let c = point(), r = rng.double(in: 0.05..<0.2)
                let shade = rng.double(in: 0.7..<1.35)
                d.ellipse(Rect(center: c, size: Vec2(r * 2, r * rng.double(in: 1.1..<1.7))),
                          base.shaded(shade), minDetail: r > 0.12 ? 10 : 20)
            }
        case .bedrock:
            // Bedding planes.
            var y = band.maxY - rng.double(in: 0.8..<1.6)
            while y > band.minY {
                d.line([Vec2(band.minX, y), Vec2(band.maxX, y + rng.double(in: -0.3..<0.3))],
                       base.shaded(0.8).withAlpha(0.6), width: 0.04, minDetail: 6)
                y -= rng.double(in: 1.2..<2.4)
            }
            // Jagged fissures.
            for _ in 0..<Int(area * 0.06) {
                var a = point()
                var pts = [a]
                for _ in 0..<Int(rng.int(in: 2..<5)) {
                    a = a + Vec2(rng.double(in: -0.4..<0.4), -rng.double(in: 0.2..<0.7))
                    pts.append(a)
                }
                d.line(pts, base.shaded(0.62).withAlpha(0.8), width: 0.03, minDetail: 12)
            }
            for _ in 0..<Int(area * 0.8) {
                dot(point(), rng.double(in: 0.02..<0.06), base.shaded(rng.double(in: 0.8..<1.25)).withAlpha(0.7), 36)
            }
        case .paving:
            break
        }
    }
}
