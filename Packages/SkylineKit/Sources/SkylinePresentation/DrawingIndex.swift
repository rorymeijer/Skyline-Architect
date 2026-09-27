import Foundation
import SkylineCore

/// Uniform-grid spatial index over a `Drawing`: answers "which items may touch this
/// region?" in painter's order. Very large items (sky bands, strata spanning kilometres)
/// go to a small always-checked list instead of thousands of buckets.
public struct DrawingIndex: Sendable {
    public let cellSize: Double
    private struct Cell: Hashable, Sendable { var x: Int32; var y: Int32 }
    private var buckets: [Cell: [Int32]] = [:]
    private var large: [Int32] = []
    public let itemCount: Int

    /// Items covering more than this many cells are stored in the large list.
    static let largeItemCellLimit = 64

    public init(_ drawing: Drawing, cellSize: Double = 16) {
        precondition(cellSize > 0)
        self.cellSize = cellSize
        itemCount = drawing.items.count
        for (i, item) in drawing.items.enumerated() {
            let b = item.bounds
            guard !b.isNull else { continue }
            let (x0, x1, y0, y1) = cellRange(b)
            if (x1 - x0 + 1) * (y1 - y0 + 1) > Self.largeItemCellLimit {
                large.append(Int32(i))
                continue
            }
            for cx in x0...x1 {
                for cy in y0...y1 {
                    buckets[Cell(x: Int32(cx), y: Int32(cy)), default: []].append(Int32(i))
                }
            }
        }
    }

    private func cellRange(_ r: Rect) -> (Int, Int, Int, Int) {
        func c(_ v: Double) -> Int { Int(max(min((v / cellSize).rounded(.down), 1e9), -1e9)) }
        return (c(r.minX), c(r.maxX), c(r.minY), c(r.maxY))
    }

    /// Indices of items whose bounds intersect `rect` and which are visible at `detail`
    /// pixels per meter (see `Drawing.isVisible`), sorted ascending (painter's order).
    public func items(in rect: Rect, of drawing: Drawing, detail: Double = .infinity) -> [Int] {
        guard !rect.isEmpty else { return [] }
        var result = Set<Int32>()
        let (x0, x1, y0, y1) = cellRange(rect)
        if (x1 - x0 + 1) * (y1 - y0 + 1) > buckets.count {
            // Query larger than the populated grid: scan buckets instead of cells.
            for (cell, list) in buckets where cell.x >= x0 && cell.x <= x1 && cell.y >= y0 && cell.y <= y1 {
                result.formUnion(list)
            }
        } else {
            for cx in x0...x1 {
                for cy in y0...y1 {
                    if let list = buckets[Cell(x: Int32(cx), y: Int32(cy))] { result.formUnion(list) }
                }
            }
        }
        result.formUnion(large)
        return result.map(Int.init).filter {
            let item = drawing.items[$0]
            return Drawing.isVisible(item, at: detail) && item.bounds.intersects(rect)
        }.sorted()
    }
}
