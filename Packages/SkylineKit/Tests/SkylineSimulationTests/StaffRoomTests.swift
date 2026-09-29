import Foundation
import Testing
import SkylineCore
import SkylineContent
@testable import SkylineSimulation

/// Staff rooms (Phase E): they house the building's janitors and technicians, set how many
/// can be hired, and jobs far from them take longer.
@Suite struct StaffRoomTests {
    @Test func staffRoomsLimitHiring() throws {
        var f = try SimFixture(blueprint: "demo-plaza")                 // one 6-module staff room: 4 places
        let catalog = f.library.buildCatalog, rules = f.engine.rules
        #expect(FacilitiesManagement.staffCapacity(of: f.building, world: f.world, catalog: catalog) == 4)
        var hired = 0
        while FacilitiesManagement.hire(hired % 2 == 0 ? .janitor : .technician, building: f.building, world: &f.world,
                                        rules: rules, catalog: catalog) != nil { hired += 1 }
        #expect(hired == 4 && FacilitiesManagement.staffCount(of: f.building, world: f.world) == 4)
        // The demo tower has no staff room: nobody can be hired through the game.
        var tower = try SimFixture()
        #expect(FacilitiesManagement.staffCapacity(of: tower.building, world: tower.world, catalog: catalog) == 0)
        #expect(FacilitiesManagement.hire(.janitor, building: tower.building, world: &tower.world, rules: rules, catalog: catalog) == nil)
    }

    /// With nothing to do on their shift, staff wait in the staff room.
    @Test func idleStaffWaitInTheStaffRoom() throws {
        var f = try SimFixture(blueprint: "demo-plaza")
        let catalog = f.library.buildCatalog
        for role in [PersonRole.janitor, .technician] {
            FacilitiesManagement.hire(role, building: f.building, world: &f.world, rules: f.engine.rules, catalog: catalog)
        }
        f.run(until: "09:00")
        let staffRoom = try #require(f.world.rooms.values.first { $0.definitionID == "staff-room" })
        let staff = f.world.people.values.filter(\.role.isStaff)
        #expect(staff.count == 2)
        #expect(staff.allSatisfy { if case let .room(r, _) = $0.place { r == staffRoom.id } else { false } })
        f.run(until: "20:00")
        #expect(f.world.people.values.filter(\.role.isStaff).allSatisfy { $0.place == .outside })
    }

    /// A staff room reaches `staffRange` floors up and down.
    @Test func jobsFarFromTheStaffRoomAreOutOfRange() throws {
        let f = try SimFixture(blueprint: "demo-plaza")                 // staff room on floor 3, range 10
        let catalog = f.library.buildCatalog
        #expect(FacilitiesManagement.isNearStaffRoom(13, in: f.building, world: f.world, catalog: catalog))
        #expect(!FacilitiesManagement.isNearStaffRoom(14, in: f.building, world: f.world, catalog: catalog))
        #expect(FacilitiesManagement.isNearStaffRoom(-1, in: f.building, world: f.world, catalog: catalog))
    }
}
