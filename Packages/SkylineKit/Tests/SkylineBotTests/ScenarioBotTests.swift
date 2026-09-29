import Foundation
import Testing
import SkylineCore
import SkylineContent
@testable import SkylineBot

/// The balance bot (F1).
@Suite struct ScenarioBotTests {
    @Test func unitsSplitIntoRoomsWithinTheirLimits() {
        #expect(TowerPlan.split(ColumnSpan(start: 0, count: 11), min: 6, max: 16) == [ColumnSpan(start: 0, count: 11)])
        #expect(TowerPlan.split(ColumnSpan(start: 0, count: 15), min: 6, max: 10) == [ColumnSpan(start: 0, count: 8), ColumnSpan(start: 8, count: 7)])
        #expect(TowerPlan.split(ColumnSpan(start: 0, count: 4), min: 6, max: 10).isEmpty)
    }

    /// The bot plays Opening Day like a player (charged construction, the market does the
    /// leasing) and wins it.
    @Test func botWinsOpeningDay() throws {
        var bot = ScenarioBot(library: try ContentLibrary.loadBase())
        let r = try bot.play("opening-day")
        print("[bot] Opening Day: \(r.result.map { $0.won ? "won" : "lost" } ?? "undecided") day \(r.days), floors \(r.floors), units \(r.units), " + r.log.joined(separator: " · "))
        #expect(r.result?.won == true)
        #expect(r.floors >= 3 && r.units >= 12)
    }
}
