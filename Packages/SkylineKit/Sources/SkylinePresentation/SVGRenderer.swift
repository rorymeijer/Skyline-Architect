import Foundation
import SkylineCore

/// Renders a composition view to SVG — the headless counterpart of the app's CoreGraphics
/// rasterizer, used for design review on machines without the app (CI, Linux).
/// Output is a *design preview of the composition*, not a game screenshot.
public enum SVGRenderer {
    public struct Options: Sendable {
        public var pixelsPerMeter: Double
        public var gridOverlay: GridOverlay?
        public var palette: ArtPalette
        public var caption: String?

        public init(pixelsPerMeter: Double, gridOverlay: GridOverlay? = nil, palette: ArtPalette = .standard, caption: String? = nil) {
            self.pixelsPerMeter = pixelsPerMeter
            self.gridOverlay = gridOverlay
            self.palette = palette
            self.caption = caption
        }
    }

    public static func render(_ c: SiteComposition, view: Rect, options o: Options) -> String {
        let ppm = o.pixelsPerMeter
        let w = view.width * ppm, h = view.height * ppm
        var defs = ""
        var body = ""
        var gradientCount = 0

        func paintAttr(_ paint: Paint) -> String {
            switch paint {
            case .solid(let c): return "fill=\"\(rgb(c))\"\(c.a < 1 ? " fill-opacity=\"\(n(c.a))\"" : "")"
            case .linear(let s, let e, let stops):
                gradientCount += 1
                let id = "g\(gradientCount)"
                defs += "<linearGradient id=\"\(id)\" gradientUnits=\"userSpaceOnUse\" x1=\"\(n(s.x))\" y1=\"\(n(s.y))\" x2=\"\(n(e.x))\" y2=\"\(n(e.y))\">"
                for st in stops {
                    defs += "<stop offset=\"\(n(st.location))\" stop-color=\"\(rgb(st.color))\" stop-opacity=\"\(n(st.color.a))\"/>"
                }
                defs += "</linearGradient>"
                return "fill=\"url(#\(id))\""
            }
        }

        // Sky (world-anchored gradient).
        let sky = c.sky
        body += "<rect x=\"\(n(view.minX))\" y=\"\(n(view.minY))\" width=\"\(n(view.width))\" height=\"\(n(view.height))\" "
        body += paintAttr(.linear(start: Vec2(0, 0), end: Vec2(0, sky.top),
                                  stops: sky.stops.map { GradientStop($0.altitude / sky.top, $0.color) })) + "/>\n"

        for i in c.index.items(in: view, of: c.drawing, detail: ppm) {
            let item = c.drawing.items[i]
            let fill = item.fill.map(paintAttr) ?? "fill=\"none\""
            var stroke = ""
            if let s = item.stroke {
                stroke = " stroke=\"\(rgb(s.color))\" stroke-opacity=\"\(n(s.color.a))\" stroke-width=\"\(n(s.width))\""
                if !s.dash.isEmpty { stroke += " stroke-dasharray=\"\(s.dash.map(n).joined(separator: " "))\"" }
            }
            body += element(item.shape, attrs: fill + stroke) + "\n"
        }

        if let g = o.gridOverlay {
            let px = 1 / ppm
            for line in g.lines {
                let (color, width, dash) = gridStyle(line.style, o.palette, px: px)
                body += "<line x1=\"\(n(line.from.x))\" y1=\"\(n(line.from.y))\" x2=\"\(n(line.to.x))\" y2=\"\(n(line.to.y))\" stroke=\"\(rgb(color))\" stroke-opacity=\"\(n(color.a))\" stroke-width=\"\(n(width))\"\(dash.isEmpty ? "" : " stroke-dasharray=\"\(dash.map(n).joined(separator: " "))\"")/>\n"
            }
        }

        var overlay = ""
        if let g = o.gridOverlay {
            let labelX = (max(view.minX, c.frontageRect.minX) - view.minX) * ppm - 6
            for label in g.labels {
                let y = (view.maxY - label.y) * ppm + 4
                overlay += "<text x=\"\(n(max(labelX, 24)))\" y=\"\(n(y))\" font-family=\"Helvetica, Arial, sans-serif\" font-size=\"11\" text-anchor=\"end\" fill=\"\(rgb(o.palette.gridLabel))\">\(label.text)</text>\n"
            }
        }
        if let caption = o.caption {
            overlay += "<rect x=\"0\" y=\"\(n(h - 22))\" width=\"\(n(w))\" height=\"22\" fill=\"#000\" fill-opacity=\"0.55\"/>"
            overlay += "<text x=\"8\" y=\"\(n(h - 7))\" font-family=\"Helvetica, Arial, sans-serif\" font-size=\"12\" fill=\"#fff\">\(escape(caption))</text>\n"
        }

        let transform = "matrix(\(n(ppm)) 0 0 \(n(-ppm)) \(n(-view.minX * ppm)) \(n(view.maxY * ppm)))"
        return """
        <svg xmlns="http://www.w3.org/2000/svg" width="\(Int(w.rounded()))" height="\(Int(h.rounded()))" viewBox="0 0 \(n(w)) \(n(h))">
        <defs>\(defs)</defs>
        <rect width="100%" height="100%" fill="\(rgb(sky.zenith))"/>
        <g transform="\(transform)">
        \(body)</g>
        \(overlay)</svg>
        """
    }

    static func gridStyle(_ s: GridLineStyle, _ p: ArtPalette, px: Double) -> (RGBA, Double, [Double]) {
        switch s {
        case .module: (p.gridModule, px, [])
        case .bay: (p.gridBay, px, [])
        case .floor: (p.gridFloor, px, [])
        case .floorMajor: (p.gridFloorMajor, px * 1.5, [])
        case .grade: (p.gridGrade, px * 1.5, [])
        case .plotBoundary: (p.plotBoundary, px * 1.5, [6 * px, 4 * px])
        }
    }

    private static func element(_ shape: DrawShape, attrs: String) -> String {
        switch shape {
        case .rect(let r):
            return "<rect x=\"\(n(r.minX))\" y=\"\(n(r.minY))\" width=\"\(n(r.width))\" height=\"\(n(r.height))\" \(attrs)/>"
        case .ellipse(let r):
            return "<ellipse cx=\"\(n(r.center.x))\" cy=\"\(n(r.center.y))\" rx=\"\(n(r.width / 2))\" ry=\"\(n(r.height / 2))\" \(attrs)/>"
        case .polygon(let pts):
            return "<polygon points=\"\(points(pts))\" \(attrs)/>"
        case .polyline(let pts):
            return "<polyline points=\"\(points(pts))\" \(attrs)/>"
        }
    }

    private static func points(_ pts: [Vec2]) -> String { pts.map { "\(n($0.x)),\(n($0.y))" }.joined(separator: " ") }

    static func rgb(_ c: RGBA) -> String {
        func b(_ v: Double) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return "rgb(\(b(c.r)),\(b(c.g)),\(b(c.b)))"
    }

    /// Compact, locale-independent number formatting.
    static func n(_ v: Double) -> String {
        if !v.isFinite { return v > 0 ? "1e9" : "-1e9" }
        let r = (v * 1000).rounded() / 1000
        if r == r.rounded() && abs(r) < 1e15 { return String(Int(r)) }
        return String(r)
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
    }
}
