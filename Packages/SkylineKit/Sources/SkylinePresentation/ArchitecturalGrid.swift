import Foundation
import SkylineCore

public enum GridLineStyle: Int, CaseIterable, Sendable {
    case module, bay, floor, floorMajor, grade, plotBoundary
}

public struct GridLine: Hashable, Sendable {
    public var from: Vec2
    public var to: Vec2
    public var style: GridLineStyle
}

public struct GridLabel: Hashable, Sendable {
    public var floor: Int
    public var text: String
    /// World y of the label's vertical center (middle of the storey).
    public var y: Double
}

/// Grid overlay for the current view. Line count is bounded by screen size, not world
/// size: strides grow as you zoom out so lines never get denser than `minSpacing`.
public struct GridOverlay: Sendable {
    public var lines: [GridLine]
    public var labels: [GridLabel]
    /// Floors between consecutive horizontal lines / labels.
    public var floorStride: Int
    public var labelStride: Int
    /// Columns between consecutive vertical lines (0 = no vertical lines).
    public var columnStride: Int
}

public enum ArchitecturalGrid {
    /// Minimum on-screen spacing of grid lines, in points.
    public static let minLineSpacing = 7.0
    /// Minimum on-screen spacing of floor labels, in points.
    public static let minLabelSpacing = 18.0
    static let floorStrides = [1, 2, 5, 10, 25, 50, 100, 250, 500, 1000, 2500]

    /// Builds the overlay for the buildable frontage of `plot` inside `visible`.
    /// The grid extends from the deepest permitted basement upward without limit.
    public static func build(grid: GridSpec, plot: Plot, visible: Rect, zoom: Double) -> GridOverlay {
        let x0 = grid.x(ofColumn: plot.frontage.start), x1 = grid.x(ofColumn: plot.frontage.end)
        let bottom = grid.y(ofFloor: -plot.maxBasementFloors)
        let region = Rect(minX: x0, minY: bottom, maxX: x1, maxY: max(visible.maxY, bottom))
        let clip = region.intersection(visible)
        var lines: [GridLine] = []
        var labels: [GridLabel] = []

        let floorStride = stride(for: grid.floorHeight * zoom, candidates: floorStrides)
        let labelStride = stride(for: grid.floorHeight * zoom, candidates: floorStrides, minSpacing: minLabelSpacing)
        let columnCandidates = [1, grid.bayModules, grid.bayModules * 2, grid.bayModules * 4]
        let colStrideRaw = stride(for: grid.moduleWidth * zoom, candidates: columnCandidates)
        let columnStride = grid.moduleWidth * Double(colStrideRaw) * zoom >= minLineSpacing ? colStrideRaw : 0

        if !clip.isEmpty {
            // Horizontal floor lines.
            let fLo = grid.floor(atY: clip.minY), fHi = grid.floor(atY: clip.maxY) + 1
            var f = roundUp(fLo, to: floorStride)
            while f <= fHi {
                let y = grid.y(ofFloor: f)
                if y >= clip.minY && y <= clip.maxY {
                    let style: GridLineStyle = f == 0 ? .grade : (f % (floorStride * 5) == 0 ? .floorMajor : .floor)
                    lines.append(GridLine(from: Vec2(clip.minX, y), to: Vec2(clip.maxX, y), style: style))
                }
                f += floorStride
            }
            if floorStride > 1, clip.minY <= 0, clip.maxY >= 0, !lines.contains(where: { $0.style == .grade }) {
                lines.append(GridLine(from: Vec2(clip.minX, 0), to: Vec2(clip.maxX, 0), style: .grade))
            }
            // Vertical module / bay lines.
            if columnStride > 0 {
                let cLo = grid.column(atX: clip.minX), cHi = grid.column(atX: clip.maxX) + 1
                var c = roundUp(cLo, to: columnStride)
                while c <= cHi {
                    let x = grid.x(ofColumn: c)
                    if x > x0 && x < x1 && x >= clip.minX && x <= clip.maxX {
                        let style: GridLineStyle = grid.isBayLine(column: c) ? .bay : .module
                        lines.append(GridLine(from: Vec2(x, clip.minY), to: Vec2(x, clip.maxY), style: style))
                    }
                    c += columnStride
                }
            }
            // Floor labels.
            var lf = roundUp(fLo, to: labelStride)
            while lf <= fHi {
                let mid = grid.y(ofFloor: lf) + grid.floorHeight / 2
                if lf >= -plot.maxBasementFloors && mid >= clip.minY && mid <= clip.maxY {
                    labels.append(GridLabel(floor: lf, text: FloorLabel.label(for: lf), y: mid))
                }
                lf += labelStride
            }
        }
        // Plot boundary lines run from the deepest basement upward, clipped to the view.
        for x in [x0, x1] where x >= visible.minX && x <= visible.maxX {
            let lo = max(bottom, visible.minY), hi = visible.maxY
            if hi > lo { lines.append(GridLine(from: Vec2(x, lo), to: Vec2(x, hi), style: .plotBoundary)) }
        }
        return GridOverlay(lines: lines, labels: labels, floorStride: floorStride, labelStride: labelStride, columnStride: columnStride)
    }

    /// Smallest candidate whose spacing (`unitSpacing × candidate`) is at least `minSpacing`.
    static func stride(for unitSpacing: Double, candidates: [Int], minSpacing: Double = minLineSpacing) -> Int {
        candidates.first { Double($0) * unitSpacing >= minSpacing } ?? candidates.last!
    }

    static func roundUp(_ v: Int, to s: Int) -> Int {
        let r = ((v % s) + s) % s
        return r == 0 ? v : v + (s - r)
    }
}
