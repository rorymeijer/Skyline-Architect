import Foundation
import SkylineCore

/// Distant city silhouettes in two atmospheric depth bands, generated from the city seed.
enum BackdropArt {
    /// Buildings are drawn at reduced scale (they stand kilometres behind the plot in an
    /// orthographic view, so true scale would make them look adjacent).
    /// `lights` receives the windows that glow at night (the emission layer, Phase 12).
    /// Lit windows inside `avoid` (the neighbours standing in front) are left out.
    static func draw(into d: inout Drawing, lights: inout Drawing, avoid: [Rect] = [], span: ClosedRange<Double>, focusX: Double,
                     palette p: ArtPalette, seed: UInt64) {
        var rng = SeededRandom(seed: seed, stream: 0xBAC)
        let width = span.upperBound - span.lowerBound
        for (band, color, heightScale) in [(0, p.backdropFar, 1.3), (1, p.backdropNear, 1.0)] {
            var x = span.lowerBound
            while x < span.upperBound {
                let w = rng.double(in: 5..<16)
                if rng.chance(0.15) { x += w * 0.7; continue }  // gaps between blocks
                // Taller buildings cluster toward the downtown focus.
                let distance = abs(x - focusX) / width
                let tallness = max(0.1, 1 - distance * 5)
                let h = rng.double(in: 5..<(14 + 66 * tallness)) * heightScale
                let r = Rect(minX: x, minY: 0, maxX: x + w, maxY: h)
                let shade = color.shaded(rng.double(in: 0.96..<1.04))
                if h > 30, rng.chance(0.3) {
                    // Setback crown.
                    let inset = w * rng.double(in: 0.15..<0.3)
                    let crown = h + rng.double(in: 3..<10)
                    d.polygon([Vec2(r.minX, 0), Vec2(r.maxX, 0), Vec2(r.maxX, h), Vec2(r.maxX - inset, h),
                               Vec2(r.maxX - inset, crown), Vec2(r.minX + inset, crown), Vec2(r.minX + inset, h),
                               Vec2(r.minX, h)], shade)
                } else {
                    d.fill(r, shade)
                }
                if band == 1, abs(x - focusX) < 900 {
                    // Floor bands read as windows at a distance.
                    var fy = 1.8
                    while fy < h - 1 {
                        d.fill(Rect(minX: r.minX + 0.4, minY: fy, maxX: r.maxX - 0.4, maxY: fy + 0.55), p.backdropFloorBand, minDetail: 8)
                        fy += 1.6
                    }
                }
                if abs(x - focusX) < 1600 {
                    NightArt.cityWindows(into: &lights, building: r, share: band == 1 ? 0.3 : 0.14, avoid: avoid,
                                         seed: seed ^ UInt64(bitPattern: Int64((x * 10).rounded())) ^ UInt64(band))
                }
                x += w + rng.double(in: 0..<3)
            }
        }
        // Atmospheric haze toward the horizon.
        d.verticalGradient(Rect(minX: span.lowerBound, minY: 0, maxX: span.upperBound, maxY: 90),
                           top: p.skyHorizon.withAlpha(0), bottom: p.skyHorizon.withAlpha(0.6))
    }
}

/// Mid-ground neighbouring buildings standing on the site margins, drawn as muted
/// elevations (not cut away) to give the plot scale and context.
enum NeighborArt {
    enum Style { case masonry, glass }

    static func draw(into d: inout Drawing, lights: inout Drawing, rect: Rect, style: Style, grid: GridSpec, palette p: ArtPalette, seed: UInt64) {
        var rng = SeededRandom(seed: seed, stream: 0x4E)
        var night = SeededRandom(seed: seed, stream: 0x416)
        let floors = Int(rect.height / grid.floorHeight)
        switch style {
        case .masonry:
            d.verticalGradient(rect, top: p.neighborMasonry.shaded(1.02), bottom: p.neighborMasonry.shaded(0.9))
            // Plinth and cornice.
            d.fill(Rect(minX: rect.minX, minY: 0, maxX: rect.maxX, maxY: 1.2), p.neighborStone.shaded(0.9))
            d.fill(Rect(minX: rect.minX - 0.4, minY: rect.maxY - 0.6, maxX: rect.maxX + 0.4, maxY: rect.maxY), p.neighborStone)
            // Punched windows with stone sills.
            let bays = max(1, Int(rect.width / 3.2))
            let bayW = rect.width / Double(bays)
            for f in 0..<floors {
                let fy = Double(f) * grid.floorHeight
                for b in 0..<bays {
                    let wx = rect.minX + Double(b) * bayW + bayW * 0.28
                    let win = Rect(minX: wx, minY: fy + 1.1, maxX: wx + bayW * 0.44, maxY: fy + 3.1)
                    guard win.maxY < rect.maxY - 0.8 else { continue }
                    d.fill(win, p.neighborWindow.shaded(rng.double(in: 0.9..<1.15)), minDetail: 1.5)
                    if night.chance(0.35) { lights.fill(win, NightArt.windowColor(&night)) }
                    d.fill(Rect(minX: win.minX - 0.1, minY: win.minY - 0.15, maxX: win.maxX + 0.1, maxY: win.minY),
                           p.neighborStone, minDetail: 6)
                    d.fill(Rect(minX: win.center.x - 0.03, minY: win.minY, maxX: win.center.x + 0.03, maxY: win.maxY),
                           p.neighborStone.shaded(0.9), minDetail: 10)
                }
            }
        case .glass:
            d.verticalGradient(rect, top: p.neighborGlass.shaded(1.12), bottom: p.neighborGlass.shaded(0.92))
            // Spandrel bands and mullions.
            for f in 0..<floors {
                let fy = Double(f) * grid.floorHeight
                d.fill(Rect(minX: rect.minX, minY: fy, maxX: rect.maxX, maxY: fy + 0.9), p.neighborMullion.shaded(0.85), minDetail: 1.5)
                guard fy + grid.floorHeight < rect.maxY - 1 else { continue }
                var wx = rect.minX
                while wx + 1.5 <= rect.maxX {
                    if night.chance(0.3) {
                        lights.fill(Rect(minX: wx + 0.08, minY: fy + 0.95, maxX: wx + 1.42, maxY: fy + grid.floorHeight - 0.1), NightArt.windowColor(&night))
                    }
                    wx += 1.5
                }
            }
            var mx = rect.minX
            while mx <= rect.maxX {
                d.fill(Rect(minX: mx - 0.05, minY: 0, maxX: mx + 0.05, maxY: rect.maxY), p.neighborMullion, minDetail: 5)
                mx += 1.5
            }
            // Sky reflection sheen.
            d.add(DrawItem(shape: .rect(rect), fill: .linear(
                start: Vec2(rect.minX, rect.minY), end: Vec2(rect.maxX, rect.maxY),
                stops: [GradientStop(0, RGBA(1, 1, 1, 0)), GradientStop(0.55, RGBA(1, 1, 1, 0.14)), GradientStop(1, RGBA(1, 1, 1, 0))])))
            d.fill(Rect(minX: rect.minX, minY: rect.maxY - 1.2, maxX: rect.maxX, maxY: rect.maxY), p.neighborMullion.shaded(0.8))
        }
        // Contact shadow at the base.
        d.verticalGradient(Rect(minX: rect.minX, minY: 0, maxX: rect.maxX, maxY: 1.5),
                           top: RGBA(0, 0, 0, 0), bottom: RGBA(0, 0, 0, 0.25))
    }
}
