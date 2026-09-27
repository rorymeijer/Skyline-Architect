import Testing
@testable import SkylineCore

@Suite struct GridTests {
    let grid = GridSpec.standard

    @Test(arguments: [(0.0, 0), (3.99, 0), (4.0, 1), (-0.01, -1), (-4.0, -1), (-4.01, -2), (400.0, 100)])
    func floorAtY(y: Double, expected: Int) {
        #expect(grid.floor(atY: y) == expected)
    }

    @Test func columnAtX() {
        #expect(grid.column(atX: 0) == 0)
        #expect(grid.column(atX: 0.999) == 0)
        #expect(grid.column(atX: -0.5) == -1)
    }

    @Test func labels() {
        #expect(FloorLabel.label(for: 0) == "G")
        #expect(FloorLabel.label(for: 12) == "12")
        #expect(FloorLabel.label(for: -2) == "B2")
    }

    /// No hard floor limit: very tall buildings must map cleanly.
    @Test func veryTallFloorsRoundTrip() {
        for f in [500, 2_000, 10_000] {
            #expect(grid.floor(atY: grid.y(ofFloor: f) + 0.1) == f)
        }
    }

    @Test func spans() {
        let a = ColumnSpan(start: 4, count: 8)
        #expect(a.end == 12)
        #expect(a.contains(ColumnSpan(start: 4, count: 8)))
        #expect(!a.contains(ColumnSpan(start: 3, count: 2)))
        #expect(a.overlaps(ColumnSpan(start: 11, count: 5)))
        #expect(!a.overlaps(ColumnSpan(start: 12, count: 5)))
        let r = grid.rect(columns: a, floors: FloorSpan(lowest: -1, highest: 1))
        #expect(r == Rect(minX: 4, minY: -4, maxX: 12, maxY: 8))
        #expect(grid.isBayLine(column: 16) && !grid.isBayLine(column: 12))
    }
}
