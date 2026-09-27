import Testing
@testable import SkylineCore

@Suite struct ElevatorMotionTests {
    @Test func durationsFollowTheVelocityProfile() {
        // Long trip: cruise phase. 40 m at 2.5 m/s, 1 m/s²: 40/2.5 + 2.5 = 18.5 s.
        #expect(abs(ElevatorMotion.duration(distance: 40, speed: 2.5, acceleration: 1) - 18.5) < 1e-9)
        // Short trip: triangular. 4 m at 1 m/s² never reaches 2.5 m/s: 2·√4 = 4 s.
        #expect(abs(ElevatorMotion.duration(distance: 4, speed: 2.5, acceleration: 1) - 4) < 1e-9)
        #expect(ElevatorMotion.duration(distance: 0, speed: 2.5, acceleration: 1) == 0)
    }

    @Test func distanceIsContinuousAndMonotonic() {
        for d in [4.0, 6.25, 40.0, 400.0] {
            let total = ElevatorMotion.duration(distance: d, speed: 2.5, acceleration: 1)
            var last = 0.0
            for i in 0...200 {
                let x = ElevatorMotion.distance(after: total * Double(i) / 200, of: d, speed: 2.5, acceleration: 1)
                #expect(x >= last - 1e-9)
                #expect(x - last < d / 50 + 1e-9)       // no jumps
                last = x
            }
            #expect(abs(last - d) < 1e-9)
            #expect(ElevatorMotion.distance(after: -1, of: d, speed: 2.5, acceleration: 1) == 0)
        }
    }

    @Test func carPositionAndDoors() {
        let grid = GridSpec.standard
        var car = ElevatorCar(id: RoomID(raw: 7), buildingID: BuildingID(raw: 1), floor: 2)
        #expect(ElevatorMotion.y(of: car, at: 5, grid: grid) == 8)
        let ticks = ElevatorMotion.ticks(floors: -2, grid: grid, speed: 2.5, acceleration: 1)
        #expect(ticks == 6)                                  // 8 m ≥ 6.25 m: 8/2.5 + 2.5 = 5.7 s → 6 ticks
        car.motion = .moving(fromFloor: 2, toFloor: 0, start: 100, end: 100 + ticks, speed: 2.5, acceleration: 1)
        #expect(ElevatorMotion.y(of: car, at: 100, grid: grid) == 8)
        #expect(ElevatorMotion.y(of: car, at: Double(100 + ticks), grid: grid) == 0)
        let mid = ElevatorMotion.y(of: car, at: 102.5, grid: grid)
        #expect(mid > 0 && mid < 8)
        car.motion = .stopped(since: 200, until: 210)
        #expect(ElevatorMotion.doorOpening(of: car, at: 200) == 0)
        #expect(ElevatorMotion.doorOpening(of: car, at: 205) == 1)
        #expect(ElevatorMotion.doorOpening(of: car, at: 209) == 0.5)
    }
}
