import Foundation
import SkylineCore

/// A furniture instance positioned in world space.
public struct PlacedFurniture: Hashable, Sendable {
    public var furniture: String
    /// World x of the piece's left edge and y of its base.
    public var x: Double
    public var y: Double
    public var flip: Bool
    public var variant: Int
}

/// Turns an `InteriorLayout` into concrete placements for a room of a given width.
/// Deterministic and pure: fixed items first (left/right/center anchors, skipped if they
/// do not fit or collide), then repeat groups fill the widest remaining free interval.
public enum LayoutResolver {
    public static func resolve(_ layout: InteriorLayout, catalog: ArtCatalog, x0: Double, x1: Double,
                               floorY: Double, seed: UInt64) -> [PlacedFurniture] {
        let width = x1 - x0
        var reserved: [(Double, Double)] = []
        var wallItems: [PlacedFurniture] = []
        var floorItems: [PlacedFurniture] = []
        var instance: UInt64 = 0

        func variant(for def: FurnitureDefinition) -> Int {
            defer { instance += 1 }
            guard let count = def.variants?.count, count > 1 else { return 0 }
            var rng = SeededRandom(seed: seed, stream: instance)
            return rng.int(in: 0..<count)
        }
        func free(_ a: Double, _ b: Double) -> Bool {
            a >= x0 - 1e-9 && b <= x1 + 1e-9 && !reserved.contains { $0.0 < b - 1e-9 && a < $0.1 - 1e-9 }
        }

        func applies(_ item: InteriorLayout.Item) -> Bool {
            if let min = item.minRoomWidth, width < min - 1e-9 { return false }
            if let max = item.maxRoomWidth, width > max + 1e-9 { return false }
            return true
        }

        for item in layout.items {
            guard applies(item) else { continue }
            guard let id = item.furniture, let def = catalog.furniture[id] else { continue }
            let offset = item.offset ?? 0
            let x: Double
            switch item.anchor ?? .left {
            case .left: x = x0 + offset
            case .right: x = x1 - offset - def.width
            case .center: x = (x0 + x1) / 2 - def.width / 2 + offset
            }
            let reserves = item.reserve ?? true
            if reserves {
                guard free(x, x + def.width) else { continue }
                reserved.append((x, x + def.width))
            } else if x < x0 - 1e-9 || x + def.width > x1 + 1e-9 {
                continue
            }
            let placed = PlacedFurniture(furniture: id, x: x, y: floorY + (item.elevation ?? 0),
                                         flip: item.flip ?? false, variant: variant(for: def))
            if reserves { floorItems.append(placed) } else { wallItems.append(placed) }
        }

        for item in layout.items {
            guard let group = item.repeat, applies(item) else { continue }
            let margin = group.margin ?? 0.3
            let extent = group.items.compactMap { gi in catalog.furniture[gi.furniture].map { gi.offset + $0.width } }.max() ?? 0
            guard extent > 0, let gap = widestGap(x0: x0, x1: x1, reserved: reserved, margin: margin), gap.1 - gap.0 >= extent else { continue }
            let count = Int(((gap.1 - gap.0 - extent) / group.spacing).rounded(.down)) + 1
            let run = Double(count - 1) * group.spacing + extent
            let start = gap.0 + (gap.1 - gap.0 - run) / 2
            for k in 0..<count {
                let gx = start + Double(k) * group.spacing
                for gi in group.items {
                    guard let def = catalog.furniture[gi.furniture] else { continue }
                    floorItems.append(PlacedFurniture(furniture: gi.furniture, x: gx + gi.offset, y: floorY + (gi.elevation ?? 0),
                                                      flip: gi.flip ?? false, variant: variant(for: def)))
                }
            }
            reserved.append((start, start + run))
        }
        // Wall-mounted items are drawn first so furniture stands in front of them.
        return wallItems + floorItems
    }

    /// Widest interval inside [x0, x1] not covered by reserved intervals (shrunk by margin).
    static func widestGap(x0: Double, x1: Double, reserved: [(Double, Double)], margin: Double) -> (Double, Double)? {
        var cursor = x0
        var best: (Double, Double)?
        for r in reserved.sorted(by: { $0.0 < $1.0 }) {
            if r.0 > cursor { best = wider(best, (cursor + margin, r.0 - margin)) }
            cursor = max(cursor, r.1)
        }
        if x1 > cursor { best = wider(best, (cursor + margin, x1 - margin)) }
        return best.flatMap { $0.1 > $0.0 ? $0 : nil }
    }

    private static func wider(_ a: (Double, Double)?, _ b: (Double, Double)) -> (Double, Double) {
        guard let a else { return b }
        return (b.1 - b.0) > (a.1 - a.0) ? b : a
    }
}

/// Draws furniture recipes into a drawing.
enum FurnitureArt {
    /// Default minimum raster density of furniture: hidden at massing / skyline zoom.
    static let defaultMinDetail = 10.0

    static func draw(into d: inout Drawing, _ placed: PlacedFurniture, catalog: ArtCatalog) {
        guard let def = catalog.furniture[placed.furniture] else { return }
        let variant = def.variants.flatMap { $0.indices.contains(placed.variant) ? $0[placed.variant] : $0.first }
        for part in def.parts {
            var key = part.material
            if key.hasPrefix("$") { key = variant?[String(key.dropFirst())] ?? "" }
            guard var color = catalog.materials[key] else { continue }
            if let o = part.opacity { color = color.withAlpha(color.a * o) }
            let detail = part.minDetail ?? def.minDetail ?? defaultMinDetail
            func wx(_ lx: Double, _ lw: Double = 0) -> Double {
                placed.flip ? placed.x + def.width - lx - lw : placed.x + lx
            }
            switch part.shape {
            case .rect, .ellipse:
                guard let x = part.x, let y = part.y, let w = part.w, let h = part.h else { continue }
                let r = Rect(x: wx(x, w), y: placed.y + y, width: w, height: h)
                let shape: DrawShape = part.shape == .rect ? .rect(r) : .ellipse(r)
                let paint: Paint = part.shade.map {
                    .linear(start: Vec2(r.minX, r.maxY), end: Vec2(r.minX, r.minY),
                            stops: [GradientStop(0, color), GradientStop(1, color.shaded($0))])
                } ?? .solid(color)
                d.add(DrawItem(shape: shape, fill: paint, minDetail: detail))
            case .polygon:
                let pts = (part.points ?? []).map { Vec2(wx($0[0]), placed.y + $0[1]) }
                d.add(DrawItem(shape: .polygon(pts), fill: .solid(color), minDetail: detail))
            case .line:
                let pts = (part.points ?? []).map { Vec2(wx($0[0]), placed.y + $0[1]) }
                d.add(DrawItem(shape: .polyline(pts), stroke: Stroke(color, width: part.lineWidth ?? 0.03), minDetail: detail))
            }
        }
    }
}
