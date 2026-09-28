import Foundation
import SkylineCore

/// The app icon (Phase 20), drawn with the same drawing IR and palette ideas as the game: a
/// cut-away tower at dusk — lit homes and offices, an elevator car in its shaft, a sky
/// lobby band — over its foundation, with the blueprint grid. Deterministic.
/// Canvas: 100 × 100 units, y up. `rounded` insets it on the macOS rounded-square plate
/// (the iPad icon is full-bleed; the system masks it).
public enum IconArt {
    public static let canvas = Rect(minX: 0, minY: 0, maxX: 100, maxY: 100)

    public static func drawing(rounded: Bool) -> Drawing {
        var d = Drawing()
        // macOS: 824 of 1024 px plate, corner radius ≈ 18.5 % of the plate.
        let plate = rounded ? Rect(minX: 10, minY: 10, maxX: 90, maxY: 90) : canvas
        let s = plate.width / 100
        func p(_ x: Double, _ y: Double) -> Vec2 { Vec2(plate.minX + x * s, plate.minY + y * s) }
        func r(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) -> Rect {
            Rect(minX: plate.minX + x0 * s, minY: plate.minY + y0 * s, maxX: plate.minX + x1 * s, maxY: plate.minY + y1 * s)
        }
        let outline = rounded ? roundedRect(plate, radius: 18.5 * s) : [p(0, 0), p(100, 0), p(100, 100), p(0, 100)]

        // Sky: deep blue zenith to a warm horizon.
        d.add(DrawItem(shape: .polygon(outline), fill: .linear(start: p(0, 100), end: p(0, 18), stops: [
            GradientStop(0, RGBA(hex: 0x14213D)), GradientStop(0.55, RGBA(hex: 0x3B4C7A)),
            GradientStop(0.85, RGBA(hex: 0xC07A5A)), GradientStop(1, RGBA(hex: 0xF0B26A)),
        ])))
        // Distant skyline with a few lit windows.
        let far: [(Double, Double, Double)] = [(4, 16, 40), (15, 24, 52), (24, 32, 34), (70, 78, 46), (77, 88, 58), (87, 97, 38)]
        for (x0, x1, h) in far where x1 <= 100 {
            d.add(DrawItem(shape: .rect(r(x0, 18, x1, h)), fill: .solid(RGBA(hex: 0x28355A))))
            var y = 22.0
            while y < h - 3 {
                if Int(x0 * 7 + y) % 3 == 0 { d.add(DrawItem(shape: .rect(r(x0 + 2, y, x0 + 3.2, y + 1.4)), fill: .solid(RGBA(hex: 0xF6D08C, alpha: 0.8)))) }
                y += 5
            }
        }
        // Ground and foundation.
        // The ground is the plate's outline cut at grade, so it keeps the rounded corners.
        d.add(DrawItem(shape: .polygon(clip(outline, below: p(0, 18).y)), fill: .linear(start: p(0, 18), end: p(0, 0), stops: [
            GradientStop(0, RGBA(hex: 0x5B4636)), GradientStop(1, RGBA(hex: 0x2E241D)),
        ])))
        d.add(DrawItem(shape: .rect(r(0, 17, 100, 18.6)), fill: .solid(RGBA(hex: 0x8C8C88))))
        for x in stride(from: 36.0, through: 62.0, by: 6.5) {
            d.add(DrawItem(shape: .rect(r(x, 3, x + 1.6, 17)), fill: .solid(RGBA(hex: 0xB9B4A8))))
        }
        d.add(DrawItem(shape: .rect(r(33, 13, 67, 17)), fill: .solid(RGBA(hex: 0x9E9A92))))

        // The tower: a shaft of glass with a cutaway of lit floors and a setback crown.
        let floors = 17
        let floorH = 3.6
        let base = 18.6
        d.add(DrawItem(shape: .rect(r(35, base, 65, base + Double(floors) * floorH)), fill: .solid(RGBA(hex: 0x1E2A40))))
        for f in 0..<floors {
            let y0 = base + Double(f) * floorH
            let sky = f == 9                      // the sky lobby band
            // Left units (homes, warm) and right units (offices, cool); some dark.
            let warmLit = (f * 5 + 3) % 7 != 0
            let coolLit = f < 12 ? (f * 3 + 1) % 5 != 0 : false
            let left = sky ? RGBA(hex: 0xF3E4C4) : warmLit ? RGBA(hex: 0xFFC47E) : RGBA(hex: 0x3A4459)
            let right = sky ? RGBA(hex: 0xF3E4C4) : coolLit ? RGBA(hex: 0xDCE8FF) : RGBA(hex: 0x33405A)
            d.add(DrawItem(shape: .rect(r(36, y0 + 0.5, 46.5, y0 + floorH - 0.2)), fill: .solid(left)))
            d.add(DrawItem(shape: .rect(r(53.5, y0 + 0.5, 64, y0 + floorH - 0.2)), fill: .solid(right)))
            // Slab.
            d.add(DrawItem(shape: .rect(r(34.5, y0, 65.5, y0 + 0.5)), fill: .solid(RGBA(hex: 0xC9CED6))))
        }
        // Core: elevator shaft with its car and cables.
        let top = base + Double(floors) * floorH
        d.add(DrawItem(shape: .rect(r(47.2, base, 52.8, top)), fill: .solid(RGBA(hex: 0x2A3346))))
        d.add(DrawItem(shape: .rect(r(49.9, base, 50.1, top)), fill: .solid(RGBA(hex: 0x6B7488))))
        d.add(DrawItem(shape: .rect(r(47.8, base + 10.4 * floorH / 1.5, 52.2, base + 10.4 * floorH / 1.5 + 3.2)),
                       fill: .solid(RGBA(hex: 0xF2C14E))))
        d.add(DrawItem(shape: .rect(r(34.5, top, 65.5, top + 0.8)), fill: .solid(RGBA(hex: 0xC9CED6))))
        // Crown: setback plant floor and spire.
        d.add(DrawItem(shape: .rect(r(40, top + 0.8, 60, top + 5)), fill: .solid(RGBA(hex: 0x2B3752))))
        d.add(DrawItem(shape: .rect(r(42, top + 2, 58, top + 3.4)), fill: .solid(RGBA(hex: 0xDCE8FF, alpha: 0.7))))
        d.add(DrawItem(shape: .polygon([p(49.2, top + 5), p(50.8, top + 5), p(50.1, top + 12), p(49.9, top + 12)]),
                       fill: .solid(RGBA(hex: 0xC9CED6))))
        // Blueprint grid: bay lines and grade, faint cyan.
        let cyan = RGBA(hex: 0x5FD4FF, alpha: 0.55)
        for x in [35.0, 65.0] { d.add(DrawItem(shape: .polyline([p(x, 4), p(x, 96)]), stroke: Stroke(cyan, width: 0.35 * s, dash: [1.4 * s, 1.1 * s]))) }
        d.add(DrawItem(shape: .polyline([p(4, 18.6), p(96, 18.6)]), stroke: Stroke(cyan, width: 0.35 * s, dash: [1.4 * s, 1.1 * s])))
        // A thin light rim on the plate.
        if rounded {
            d.add(DrawItem(shape: .polyline(outline + [outline[0]]), stroke: Stroke(RGBA(1, 1, 1, 0.18), width: 0.6)))
        }
        return d
    }

    /// The part of a closed polygon at or below `y` (Sutherland–Hodgman against one edge).
    static func clip(_ polygon: [Vec2], below y: Double) -> [Vec2] {
        var out: [Vec2] = []
        for (i, a) in polygon.enumerated() {
            let b = polygon[(i + 1) % polygon.count]
            if a.y <= y { out.append(a) }
            if (a.y <= y) != (b.y <= y) {
                let t = (y - a.y) / (b.y - a.y)
                out.append(Vec2(a.x + (b.x - a.x) * t, y))
            }
        }
        return out
    }

    /// Rounded rectangle as a polygon (8 points per corner).
    static func roundedRect(_ rect: Rect, radius: Double) -> [Vec2] {
        let corners: [(Vec2, Double)] = [
            (Vec2(rect.maxX - radius, rect.minY + radius), -.pi / 2), (Vec2(rect.maxX - radius, rect.maxY - radius), 0),
            (Vec2(rect.minX + radius, rect.maxY - radius), .pi / 2), (Vec2(rect.minX + radius, rect.minY + radius), .pi),
        ]
        var pts: [Vec2] = []
        for (center, start) in corners {
            for i in 0...8 {
                let a = start + Double(i) / 8 * .pi / 2
                pts.append(Vec2(center.x + radius * cos(a), center.y + radius * sin(a)))
            }
        }
        return pts
    }
}

extension SVGRenderer {
    /// A standalone drawing (world units, y up) as a square SVG of `pixels` × `pixels`.
    public static func render(drawing: Drawing, view: Rect, pixels: Int) -> String {
        let ppm = Double(pixels) / view.width
        var defs = "", body = "", gradients = 0
        func paint(_ p: Paint) -> String {
            switch p {
            case .solid(let c): return "fill=\"\(rgb(c))\"\(c.a < 1 ? " fill-opacity=\"\(n(c.a))\"" : "")"
            case .linear(let s, let e, let stops):
                gradients += 1
                defs += "<linearGradient id=\"i\(gradients)\" gradientUnits=\"userSpaceOnUse\" x1=\"\(n(s.x))\" y1=\"\(n(s.y))\" x2=\"\(n(e.x))\" y2=\"\(n(e.y))\">"
                for st in stops { defs += "<stop offset=\"\(n(st.location))\" stop-color=\"\(rgb(st.color))\" stop-opacity=\"\(n(st.color.a))\"/>" }
                defs += "</linearGradient>"
                return "fill=\"url(#i\(gradients))\""
            }
        }
        for item in drawing.items {
            var attrs = item.fill.map(paint) ?? "fill=\"none\""
            if let s = item.stroke {
                attrs += " stroke=\"\(rgb(s.color))\" stroke-opacity=\"\(n(s.color.a))\" stroke-width=\"\(n(s.width))\""
                if !s.dash.isEmpty { attrs += " stroke-dasharray=\"\(s.dash.map(n).joined(separator: " "))\"" }
            }
            body += element(item.shape, attrs: attrs) + "\n"
        }
        let transform = "matrix(\(n(ppm)) 0 0 \(n(-ppm)) \(n(-view.minX * ppm)) \(n(view.maxY * ppm)))"
        return """
        <svg xmlns="http://www.w3.org/2000/svg" width="\(pixels)" height="\(pixels)" viewBox="0 0 \(pixels) \(pixels)">
        <defs>\(defs)</defs>
        <g transform="\(transform)">
        \(body)</g>
        </svg>
        """
    }
}
