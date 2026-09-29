import Foundation
import SkylineCore

/// The player's best result per scenario (Phase C), kept on the device next to the saves —
/// not inside a save, so it survives new games and deleted saves.
public struct ScenarioRecord: Codable, Hashable, Sendable {
    public var scenarioID: String
    /// Best stars (0 = never won) and best points of any play.
    public var bestStars: Int
    public var bestScore: Int
    /// Plays decided (won or lost) and plays won.
    public var attempts: Int
    public var wins: Int
    /// Fewest days to a win.
    public var fastestDays: Int?
    public var firstWon: Date?
    public var lastPlayed: Date

    public init(scenarioID: String, bestStars: Int = 0, bestScore: Int = 0, attempts: Int = 0, wins: Int = 0,
                fastestDays: Int? = nil, firstWon: Date? = nil, lastPlayed: Date) {
        self.scenarioID = scenarioID
        self.bestStars = bestStars
        self.bestScore = bestScore
        self.attempts = attempts
        self.wins = wins
        self.fastestDays = fastestDays
        self.firstWon = firstWon
        self.lastPlayed = lastPlayed
    }
}

public struct ScenarioRecords: Codable, Hashable, Sendable {
    public var format = 1
    /// One per scenario, sorted by id.
    public private(set) var records: [ScenarioRecord] = []
    /// Results already counted ("id@tick"), so reloading a save never counts a play twice.
    public private(set) var counted: [String] = []

    public static let countedLimit = 200

    public init() {}

    public func record(for scenarioID: String) -> ScenarioRecord? { records.first { $0.scenarioID == scenarioID } }

    /// Counts a decided scenario once. Returns whether it set a new best score.
    @discardableResult
    public mutating func add(scenarioID: String, result: ScenarioResult, days: Int, at date: Date) -> Bool {
        let key = "\(scenarioID)@\(result.tick)"
        guard !counted.contains(key) else { return false }
        counted.append(key)
        if counted.count > Self.countedLimit { counted.removeFirst(counted.count - Self.countedLimit) }
        var r = record(for: scenarioID) ?? ScenarioRecord(scenarioID: scenarioID, lastPlayed: date)
        let score = result.score ?? 0
        let best = score > r.bestScore
        r.attempts += 1
        r.lastPlayed = date
        r.bestScore = max(r.bestScore, score)
        r.bestStars = max(r.bestStars, result.stars ?? (result.won ? 1 : 0))
        if result.won {
            r.wins += 1
            r.fastestDays = min(r.fastestDays ?? days, days)
            if r.firstWon == nil { r.firstWon = date }
        }
        put(r)
        return best
    }

    /// The best of both (another device's records): best stars, score and time per
    /// scenario; counts take the larger (plays may have been counted on both).
    public func merged(with other: ScenarioRecords) -> ScenarioRecords {
        var out = self
        for theirs in other.records {
            guard var mine = out.record(for: theirs.scenarioID) else { out.put(theirs); continue }
            mine.bestStars = max(mine.bestStars, theirs.bestStars)
            mine.bestScore = max(mine.bestScore, theirs.bestScore)
            mine.attempts = max(mine.attempts, theirs.attempts)
            mine.wins = max(mine.wins, theirs.wins)
            mine.fastestDays = [mine.fastestDays, theirs.fastestDays].compactMap { $0 }.min()
            mine.firstWon = [mine.firstWon, theirs.firstWon].compactMap { $0 }.min()
            mine.lastPlayed = max(mine.lastPlayed, theirs.lastPlayed)
            out.put(mine)
        }
        for key in other.counted where !out.counted.contains(key) { out.counted.append(key) }
        if out.counted.count > Self.countedLimit { out.counted.removeFirst(out.counted.count - Self.countedLimit) }
        return out
    }

    private mutating func put(_ r: ScenarioRecord) {
        records.removeAll { $0.scenarioID == r.scenarioID }
        records.append(r)
        records.sort { $0.scenarioID < $1.scenarioID }
    }
}

/// `scenario-records.json` in a folder (the saves folder; the iCloud one when syncing).
public struct ScenarioRecordStore: Sendable {
    public static let fileName = "scenario-records.json"
    public let url: URL

    public init(directory: URL) { url = directory.appendingPathComponent(Self.fileName) }

    /// The records, or empty ones when the file is missing or unreadable.
    public func load() -> ScenarioRecords {
        guard let data = try? Data(contentsOf: url) else { return ScenarioRecords() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(ScenarioRecords.self, from: data)) ?? ScenarioRecords()
    }

    public func save(_ records: ScenarioRecords) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(records).write(to: url, options: .atomic)
    }

    /// Two-way sync: both files end up with the merged records. Returns them.
    @discardableResult
    public static func sync(local: ScenarioRecordStore, remote: ScenarioRecordStore) throws -> ScenarioRecords {
        let merged = local.load().merged(with: remote.load())
        try local.save(merged)
        try remote.save(merged)
        return merged
    }
}
