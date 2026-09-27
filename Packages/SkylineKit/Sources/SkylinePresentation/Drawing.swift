import Foundation
import SkylineCore

/// Geometry of a drawing item, in world meters.
public enum DrawShape: Hashable, Sendable {
    case rect(Rect)
    case ellipse(Rect)
    /// Closed polygon.
    case polygon([Vec2])
    /// Open polyline (stroke only).
    case polyline([Vec2])

    public var bounds: Rect {
        switch self {
        case .rect(let r), .ellipse(let r): r
        case .polygon(let pts), .polyline(let pts): Rect(bounding: pts)
        }
    }
}

public struct GradientStop: Hashable, Sendable {
    public var location: Double
    public var color: RGBA
    public init(_ location: Double, _ color: RGBA) {
        self.location = location
        self.color = color
    }
}

public enum Paint: Hashable, Sendable {
    case solid(RGBA)
    /// Linear gradient between two world points (extended beyond the ends).
    case linear(start: Vec2, end: Vec2, stops: [GradientStop])
}

public struct Stroke: Hashable, Sendable {
    public var color: RGBA
    /// Line width in world meters.
    public var width: Double
    /// Optional dash pattern in meters (on, off, …).
    public var dash: [Double]

    public init(_ color: RGBA, width: Double, dash: [Double] = []) {
        self.color = color
        self.width = width
        self.dash = dash
    }
}

/// One primitive of the platform-neutral drawing IR (DECISIONS D-003).
public struct DrawItem: Hashable, Sendable {
    public var shape: DrawShape
    public var fill: Paint?
    public var stroke: Stroke?
    /// Minimum raster density (pixels per meter) at which this item is drawn.
    /// Fine detail (grain, rebar) sets this so it only appears when it can be seen.
    public var minDetail: Double
    /// Bounds including stroke width.
    public let bounds: Rect

    public init(shape: DrawShape, fill: Paint? = nil, stroke: Stroke? = nil, minDetail: Double = 0) {
        self.shape = shape
        self.fill = fill
        self.stroke = stroke
        self.minDetail = minDetail
        let pad = (stroke?.width ?? 0) / 2
        self.bounds = shape.bounds.insetBy(dx: -pad, dy: -pad)
    }
}

/// An ordered list of items (painter's order) plus named sections for inspection.
public struct Drawing: Sendable {
    public private(set) var items: [DrawItem] = []
    /// Section name → half-open item index range, in order.
    public private(set) var sections: [(name: String, range: Range<Int>)] = []

    public init() {}

    public var bounds: Rect { items.reduce(Rect.null) { $0.union($1.bounds) } }

    public mutating func add(_ item: DrawItem) { items.append(item) }

    /// Groups everything added inside `body` under a section name.
    public mutating func section(_ name: String, _ body: (inout Drawing) -> Void) {
        let start = items.count
        body(&self)
        sections.append((name, start..<items.count))
    }

    // MARK: Convenience builders

    public mutating func fill(_ rect: Rect, _ color: RGBA, minDetail: Double = 0) {
        add(DrawItem(shape: .rect(rect), fill: .solid(color), minDetail: minDetail))
    }

    /// Vertical gradient from `top` color at rect.maxY to `bottom` color at rect.minY.
    public mutating func verticalGradient(_ rect: Rect, top: RGBA, bottom: RGBA, minDetail: Double = 0) {
        add(DrawItem(shape: .rect(rect), fill: .linear(
            start: Vec2(rect.minX, rect.maxY), end: Vec2(rect.minX, rect.minY),
            stops: [GradientStop(0, top), GradientStop(1, bottom)]), minDetail: minDetail))
    }

    /// Horizontal gradient across `rect` with arbitrary stops (0 = left edge).
    public mutating func horizontalGradient(_ rect: Rect, stops: [GradientStop], minDetail: Double = 0) {
        add(DrawItem(shape: .rect(rect), fill: .linear(
            start: Vec2(rect.minX, rect.minY), end: Vec2(rect.maxX, rect.minY), stops: stops), minDetail: minDetail))
    }

    public mutating func polygon(_ points: [Vec2], _ color: RGBA, minDetail: Double = 0) {
        add(DrawItem(shape: .polygon(points), fill: .solid(color), minDetail: minDetail))
    }

    public mutating func ellipse(_ rect: Rect, _ color: RGBA, minDetail: Double = 0) {
        add(DrawItem(shape: .ellipse(rect), fill: .solid(color), minDetail: minDetail))
    }

    public mutating func line(_ points: [Vec2], _ color: RGBA, width: Double, dash: [Double] = [], minDetail: Double = 0) {
        add(DrawItem(shape: .polyline(points), stroke: Stroke(color, width: width, dash: dash), minDetail: minDetail))
    }

    public mutating func outline(_ rect: Rect, _ color: RGBA, width: Double, minDetail: Double = 0) {
        add(DrawItem(shape: .rect(rect), stroke: Stroke(color, width: width), minDetail: minDetail))
    }
}
