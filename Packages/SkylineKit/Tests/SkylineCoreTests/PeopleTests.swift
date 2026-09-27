import Testing
@testable import SkylineCore

@Suite struct ClockTests {
    @Test func dayStartsAtSix() {
        #expect(SimClock.timeString(0) == "06:00")
        #expect(SimClock.timeString(3600 * 2 + 60 * 5) == "08:05")
        #expect(SimClock.day(0) == 0)
        #expect(SimClock.day(18 * 3600) == 1)          // midnight after day 0
        #expect(SimClock.timeString(18 * 3600) == "00:00")
    }

    @Test func nextTickAtTimeOfDay() {
        // From 06:00 on day 0, the next 08:00 is two hours later.
        #expect(SimClock.nextTick(atSecondOfDay: 8 * 3600, onOrAfter: 0) == 2 * 3600)
        // The next 05:00 is the following morning (23 hours later).
        #expect(SimClock.nextTick(atSecondOfDay: 5 * 3600, onOrAfter: 0) == 23 * 3600)
        // Exactly now counts.
        #expect(SimClock.nextTick(atSecondOfDay: 6 * 3600, onOrAfter: 0) == 0)
        // Later days.
        let t: Tick = 3 * 86_400 + 5_000
        let n = SimClock.nextTick(atSecondOfDay: 12 * 3600, onOrAfter: t)
        #expect(n >= t && n - t < 86_400 && SimClock.secondOfDay(n) == 12 * 3600)
    }
}

@Suite struct MotionTests {
    let grid = GridSpec.standard

    @Test func walkingIsLinearInTime() throws {
        let legs: [Leg] = [.walk(floor: 2, fromX: 10, toX: 20, start: 100, end: 110)]
        let mid = try #require(PersonMotion.sample(legs, at: 105, grid: grid))
        #expect(mid.position == Vec2(15, 8))
        #expect(mid.direction == 1 && !mid.onStairs)
        #expect(PersonMotion.sample(legs, at: 50, grid: grid)?.position == Vec2(10, 8))
        #expect(PersonMotion.sample(legs, at: 500, grid: grid)?.position == Vec2(20, 8))
    }

    @Test func stairsZigzagBetweenFlights() throws {
        let legs: [Leg] = [.stairs(shaft: RoomID(raw: 1), fromFloor: 0, toFloor: 2, leftX: 20, rightX: 24, start: 0, end: 40)]
        let quarter = try #require(PersonMotion.sample(legs, at: 5, grid: grid))    // storey 0, first flight halfway
        #expect(abs(quarter.position.x - 22) < 1e-9 && abs(quarter.position.y - 1) < 1e-9 && quarter.direction == 1)
        let threeQ = try #require(PersonMotion.sample(legs, at: 15, grid: grid))    // storey 0, second flight halfway
        #expect(abs(threeQ.position.x - 22) < 1e-9 && threeQ.direction == -1)
        let top = try #require(PersonMotion.sample(legs, at: 40, grid: grid))
        #expect(abs(top.position.y - 8) < 1e-9)
    }

    @Test func legsChainInOrder() throws {
        let legs: [Leg] = [
            .walk(floor: 0, fromX: 0, toX: 10, start: 0, end: 10),
            .stairs(shaft: RoomID(raw: 1), fromFloor: 0, toFloor: 1, leftX: 10, rightX: 14, start: 10, end: 22),
            .walk(floor: 1, fromX: 14, toX: 20, start: 22, end: 28),
        ]
        #expect(PersonMotion.sample(legs, at: 9, grid: grid)?.onStairs == false)
        #expect(PersonMotion.sample(legs, at: 15, grid: grid)?.onStairs == true)
        #expect(PersonMotion.sample(legs, at: 25, grid: grid)?.position == Vec2(17, 4))
    }
}
