import Testing
@testable import SkylineCore

@Suite struct GeometryTests {
    @Test func rectBasics() {
        let r = Rect(x: 0, y: 0, width: 10, height: 4)
        #expect(r.width == 10)
        #expect(r.center == Vec2(5, 2))
        #expect(r.contains(Vec2(10, 4)))
        #expect(!r.isEmpty)
        #expect(Rect.null.isNull)
    }

    @Test func touchingRectsDoNotIntersect() {
        let a = Rect(x: 0, y: 0, width: 1, height: 1)
        let b = Rect(x: 1, y: 0, width: 1, height: 1)
        #expect(!a.intersects(b))
        #expect(a.intersects(Rect(x: 0.5, y: 0.5, width: 1, height: 1)))
    }

    @Test func boundingPoints() {
        let r = Rect(bounding: [Vec2(1, 5), Vec2(-2, 3), Vec2(4, -1)])
        #expect(r == Rect(minX: -2, minY: -1, maxX: 4, maxY: 5))
    }
}
