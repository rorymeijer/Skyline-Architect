import CoreGraphics
import SkylineCore
import SkylinePresentation

/// Rasterizes the platform-neutral drawing IR with CoreGraphics. Thread-safe: every call
/// uses its own bitmap context and reads only immutable composition data, so tiles can be
/// rendered on background queues (ARCHITECTURE §5, §6).
enum DrawingRasterizer {
    /// Renders `rect` of the composition at `pixelsPerMeter` into a square bitmap of
    /// `tilePixels + 2 * bleed` pixels. The bleed border repeats neighbouring content so
    /// linear filtering never samples transparent edges (no seams between tiles).
    /// Returns nil when no item touches the tile.
    static func rasterize(_ c: SiteComposition, layers: [CompositionLayer]? = nil, rect: Rect, pixelsPerMeter ppm: Double,
                          tilePixels: Int, bleed: Int = 1) -> CGImage? {
        let bleedMeters = Double(bleed) / ppm
        let area = rect.insetBy(dx: -bleedMeters, dy: -bleedMeters)
        let items = layers.map { $0.flatMap { $0.items(in: area, detail: ppm) } } ?? c.items(in: area, detail: ppm)
        guard !items.isEmpty else { return nil }
        let size = tilePixels + 2 * bleed
        guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: ColorSpaces.sRGB,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setShouldAntialias(true)
        ctx.interpolationQuality = .high
        // Bitmap origin is bottom-left with y up — the same orientation as world space.
        ctx.scaleBy(x: CGFloat(ppm), y: CGFloat(ppm))
        ctx.translateBy(x: CGFloat(-area.minX), y: CGFloat(-area.minY))
        for item in items { draw(item, in: ctx) }
        return ctx.makeImage()
    }

    /// Rasterizes a standalone drawing (e.g. a person figure) covering `rect`.
    static func rasterize(_ drawing: Drawing, rect: Rect, pixelsPerMeter ppm: Double) -> CGImage? {
        let w = max(1, Int((rect.width * ppm).rounded(.up))), h = max(1, Int((rect.height * ppm).rounded(.up)))
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: ColorSpaces.sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setShouldAntialias(true)
        ctx.scaleBy(x: CGFloat(ppm), y: CGFloat(ppm))
        ctx.translateBy(x: CGFloat(-rect.minX), y: CGFloat(-rect.minY))
        for item in drawing.items { draw(item, in: ctx) }
        return ctx.makeImage()
    }

    static func draw(_ item: DrawItem, in ctx: CGContext) {
        let path = cgPath(item.shape)
        if let fill = item.fill, !isOpen(item.shape) {
            switch fill {
            case .solid(let color):
                ctx.setFillColor(color.cgColor)
                ctx.addPath(path)
                ctx.fillPath()
            case .linear(let start, let end, let stops):
                guard let gradient = CGGradient(colorsSpace: ColorSpaces.sRGB,
                                                colors: stops.map(\.color.cgColor) as CFArray,
                                                locations: stops.map { CGFloat($0.location) }) else { break }
                ctx.saveGState()
                ctx.addPath(path)
                ctx.clip()
                ctx.drawLinearGradient(gradient, start: start.cgPoint, end: end.cgPoint,
                                       options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                ctx.restoreGState()
            }
        }
        if let stroke = item.stroke {
            ctx.setStrokeColor(stroke.color.cgColor)
            ctx.setLineWidth(CGFloat(stroke.width))
            ctx.setLineJoin(.round)
            ctx.setLineCap(.butt)
            ctx.setLineDash(phase: 0, lengths: stroke.dash.map { CGFloat($0) })
            ctx.addPath(path)
            ctx.strokePath()
        }
    }

    private static func isOpen(_ shape: DrawShape) -> Bool {
        if case .polyline = shape { return true }
        return false
    }

    static func cgPath(_ shape: DrawShape) -> CGPath {
        switch shape {
        case .rect(let r):
            return CGPath(rect: r.cgRect, transform: nil)
        case .ellipse(let r):
            return CGPath(ellipseIn: r.cgRect, transform: nil)
        case .polygon(let pts):
            let p = CGMutablePath()
            p.addLines(between: pts.map(\.cgPoint))
            p.closeSubpath()
            return p
        case .polyline(let pts):
            let p = CGMutablePath()
            p.addLines(between: pts.map(\.cgPoint))
            return p
        }
    }

    /// A 1-D vertical gradient image (bottom = first stop) used for the sky sprite.
    static func verticalGradientImage(_ sky: SkyGradient, height: Int = 256) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: 4, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: ColorSpaces.sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let gradient = CGGradient(colorsSpace: ColorSpaces.sRGB,
                                        colors: sky.stops.map(\.color.cgColor) as CFArray,
                                        locations: sky.stops.map { CGFloat($0.altitude / sky.top) }) else { return nil }
        ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: height), options: [])
        return ctx.makeImage()
    }
}
