import Foundation
import Testing
import SkylineCore
@testable import SkylinePersistence

/// The completion record (Phase C).
@Suite struct ScenarioRecordTests {
    let day = Date(timeIntervalSince1970: 1_790_000_000)

    @Test func bestResultsAreKeptAndCountedOnce() {
        var r = ScenarioRecords()
        let first = r.add(scenarioID: "opening-day", result: ScenarioResult(won: false, tick: 100, reason: "Time ran out", stars: 0, score: 60), days: 10, at: day)
        let second = r.add(scenarioID: "opening-day", result: ScenarioResult(won: true, tick: 200, reason: "Every objective met", stars: 2, score: 1500), days: 6, at: day)
        let third = r.add(scenarioID: "opening-day", result: ScenarioResult(won: true, tick: 300, reason: "x", stars: 3, score: 1400), days: 3, at: day)
        let again = r.add(scenarioID: "opening-day", result: ScenarioResult(won: true, tick: 300, reason: "x", stars: 3, score: 1400), days: 3, at: day)
        #expect(first && second && !third && !again)
        let o = r.record(for: "opening-day")!
        #expect(o.attempts == 3 && o.wins == 2 && o.bestStars == 3 && o.bestScore == 1500 && o.fastestDays == 3 && o.firstWon == day)
    }

    @Test func recordsMergeAndSyncThroughFiles() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("records-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: base) }
        let a = ScenarioRecordStore(directory: base.appendingPathComponent("a")), b = ScenarioRecordStore(directory: base.appendingPathComponent("b"))
        #expect(a.load() == ScenarioRecords())
        var ra = ScenarioRecords(), rb = ScenarioRecords()
        ra.add(scenarioID: "skyline", result: ScenarioResult(won: true, tick: 10, reason: "", stars: 1, score: 1100), days: 20, at: day)
        rb.add(scenarioID: "skyline", result: ScenarioResult(won: true, tick: 20, reason: "", stars: 2, score: 1000), days: 12, at: day.addingTimeInterval(60))
        rb.add(scenarioID: "lean-tower", result: ScenarioResult(won: false, tick: 30, reason: "", stars: 0, score: 80), days: 30, at: day)
        try a.save(ra)
        try b.save(rb)
        let merged = try ScenarioRecordStore.sync(local: a, remote: b)
        #expect(a.load() == merged && b.load() == merged)
        let s = try #require(merged.record(for: "skyline"))
        #expect(s.bestStars == 2 && s.bestScore == 1100 && s.fastestDays == 12 && s.wins == 1)
        #expect(merged.records.map(\.scenarioID) == ["lean-tower", "skyline"] && merged.counted.count == 3)
    }
}
