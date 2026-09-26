import Foundation

/// The architectural placement grid shared by all buildings.
///
/// Horizontal placement is in integer *modules* (columns); vertical placement is in
/// integer *floors*. Floor 0 is the ground floor whose slab top sits at grade (y = 0);
/// negative floors are basements. There is deliberately no floor limit.
public struct GridSpec: Codable, Hashable, Sendable {
    /// Width of one placement column in meters.
    public var moduleWidth: Double
    /// Floor-to-floor height in meters.
    public var floorHeight: Double
    /// Structural slab thickness in meters (drawn below each floor's walking surface).
    public var slabThickness: Double
    /// Structural bay width in modules; columns stand on bay lines.
    public var bayModules: Int

    public init(moduleWidth: Double, floorHeight: Double, slabThickness: Double, bayModules: Int) {
        precondition(moduleWidth > 0 && floorHeight > 0 && bayModules > 0)
        self.moduleWidth = moduleWidth
        self.floorHeight = floorHeight
        self.slabThickness = slabThickness
        self.bayModules = bayModules
    }

    public static let standard = GridSpec(moduleWidth: 1, floorHeight: 4, slabThickness: 0.35, bayModules: 8)

    /// X of the left edge of `column`.
    public func x(ofColumn column: Int) -> Double { Double(column) * moduleWidth }

    /// Column containing `x` (left edge inclusive).
    public func column(atX x: Double) -> Int { Int((x / moduleWidth).rounded(.down)) }

    /// Y of the walking surface (slab top) of `floor`.
    public func y(ofFloor floor: Int) -> Double { Double(floor) * floorHeight }

    /// Floor whose storey contains `y` (slab top inclusive).
    public func floor(atY y: Double) -> Int { Int((y / floorHeight).rounded(.down)) }

    public func isBayLine(column: Int) -> Bool { column.isMultiple(of: bayModules) }

    /// World rect covered by the given columns and floors.
    public func rect(columns: ColumnSpan, floors: FloorSpan) -> Rect {
        Rect(minX: x(ofColumn: columns.start), minY: y(ofFloor: floors.lowest),
             maxX: x(ofColumn: columns.end), maxY: y(ofFloor: floors.highest + 1))
    }

    /// Grid cell (column, floor) containing a world point.
    public func cell(at p: Vec2) -> GridCell { GridCell(column: column(atX: p.x), floor: floor(atY: p.y)) }
}

/// One module × one floor.
public struct GridCell: Hashable, Codable, Sendable, CustomStringConvertible {
    public var column: Int
    public var floor: Int
    public init(column: Int, floor: Int) {
        self.column = column
        self.floor = floor
    }
    public var description: String { "col \(column), \(FloorLabel.label(for: floor))" }
}

/// Half-open range of columns `[start, start + count)`.
public struct ColumnSpan: Hashable, Codable, Sendable, CustomStringConvertible {
    public var start: Int
    public var count: Int

    public init(start: Int, count: Int) {
        precondition(count >= 0, "ColumnSpan count must be non-negative")
        self.start = start
        self.count = count
    }

    public var end: Int { start + count }
    public var range: Range<Int> { start..<end }
    public func contains(_ column: Int) -> Bool { range.contains(column) }
    public func contains(_ other: ColumnSpan) -> Bool { other.start >= start && other.end <= end }
    public func overlaps(_ other: ColumnSpan) -> Bool { start < other.end && other.start < end }
    public var description: String { "cols \(start)..<\(end)" }
}

/// Inclusive range of floors.
public struct FloorSpan: Hashable, Codable, Sendable, CustomStringConvertible {
    public var lowest: Int
    public var highest: Int

    public init(lowest: Int, highest: Int) {
        precondition(highest >= lowest, "FloorSpan must not be inverted")
        self.lowest = lowest
        self.highest = highest
    }

    public var count: Int { highest - lowest + 1 }
    public func contains(_ floor: Int) -> Bool { floor >= lowest && floor <= highest }
    public var description: String { "\(FloorLabel.label(for: lowest))…\(FloorLabel.label(for: highest))" }
}

/// Human-readable floor names: `G`, `1`, `2`, …, `B1`, `B2`, …
public enum FloorLabel {
    public static func label(for floor: Int) -> String {
        if floor == 0 { return "G" }
        return floor > 0 ? "\(floor)" : "B\(-floor)"
    }
}
