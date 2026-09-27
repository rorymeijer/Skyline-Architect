import Foundation
import SkylineCore

public enum SaveError: Error, Equatable, CustomStringConvertible {
    case notASave
    case newerFormat(found: Int, supported: Int)
    case noMigration(from: Int)
    case migrationFailed(from: Int, reason: String)
    case corrupt(String)
    case missingContentPack(String)
    case invalidWorld(String)

    public var description: String {
        switch self {
        case .notASave: "This file is not a Skyline Architect save."
        case .newerFormat(let f, let s): "This save was made by a newer version (format \(f); this version reads up to \(s))."
        case .noMigration(let v): "No upgrade path from save format \(v)."
        case .migrationFailed(let v, let r): "Upgrading from save format \(v) failed: \(r)"
        case .corrupt(let r): "The save is damaged: \(r)"
        case .missingContentPack(let id): "The save needs content pack '\(id)', which is not installed."
        case .invalidWorld(let r): "The saved world is inconsistent: \(r)"
        }
    }
}

/// Versioned save encoding. The envelope is
/// `{ "format": "skyline-architect-save", "formatVersion": N, "game": SaveGame }`.
///
/// Older formats are upgraded step by step (`vN → vN+1`) on the untyped JSON tree before
/// typed decoding; newer formats are refused. Every decoded world is integrity-checked, so
/// an inconsistent save is rejected instead of silently corrupting a game.
public enum SaveCodec {
    public static let format = "skyline-architect-save"
    public static let currentVersion = 7

    /// Upgrades the `game` JSON object from version `key` to `key + 1`.
    public typealias Migration = @Sendable (inout [String: Any]) throws -> Void

    /// Registered upgrades; one entry per format change. Keep a fixture of every old format
    /// in the tests (SAVE_FORMAT.md).
    public static let migrations: [Int: Migration] = [
        // v1 → v2 (Phase 4): the world gains a simulation clock and people.
        1: { game in
            guard var world = game["world"] as? [String: Any] else { throw SaveError.corrupt("v1 save without world") }
            if world["clock"] == nil { world["clock"] = ["tick": 0] }
            if world["people"] == nil { world["people"] = [Any]() }
            game["world"] = world
        },
        // v2 → v3 (Phase 6): the world gains elevator cars (created for existing shafts by the
        // simulation on its next step). People's `pendingRide` is optional and absent in v2.
        2: { game in
            guard var world = game["world"] as? [String: Any] else { throw SaveError.corrupt("v2 save without world") }
            if world["elevators"] == nil { world["elevators"] = [Any]() }
            game["world"] = world
        },
        // v3 → v4 (Phase 7): cars gain a dispatch strategy and statistics.
        3: { game in
            guard var world = game["world"] as? [String: Any] else { throw SaveError.corrupt("v3 save without world") }
            let cars = (world["elevators"] as? [[String: Any]] ?? []).map { car -> [String: Any] in
                var car = car
                if car["strategy"] == nil { car["strategy"] = "collective" }
                if car["stats"] == nil {
                    car["stats"] = ["boardings": 0, "totalWait": 0, "maxWait": 0, "abandoned": 0, "stops": 0, "day": 0,
                                    "hourly": [Int](repeating: 0, count: 24)] as [String: Any]
                }
                return car
            }
            world["elevators"] = cars
            game["world"] = world
        },
        // v4 → v5 (Phase 8): the world gains tenants and a rental market. Existing people are
        // adopted into tenants by the simulation's sync on load (one tenant per room).
        4: { game in
            guard var world = game["world"] as? [String: Any] else { throw SaveError.corrupt("v4 save without world") }
            if world["tenants"] == nil { world["tenants"] = [Any]() }
            if world["market"] == nil {
                let tick = ((world["clock"] as? [String: Any])?["tick"] as? NSNumber)?.uint64Value ?? 0
                world["market"] = ["nextTick": (tick / 3600 + 1) * 3600, "prospects": 0, "signed": 0, "movedOut": 0,
                                   "declined": [Int](repeating: 0, count: 5), "log": [Any]()] as [String: Any]
            }
            game["world"] = world
        },
        // v5 → v6 (Phase 9): the world gains a ledger (older games start with no money and no
        // history) and buildings a rent level of 1.
        5: { game in
            guard var world = game["world"] as? [String: Any] else { throw SaveError.corrupt("v5 save without world") }
            if world["ledger"] == nil {
                world["ledger"] = ["cash": 0, "loans": 0, "journal": [Any](), "days": [Any](), "negativeDays": 0, "bankrupt": false] as [String: Any]
            }
            world["buildings"] = (world["buildings"] as? [[String: Any]] ?? []).map { b -> [String: Any] in
                var b = b
                if b["rentLevel"] == nil { b["rentLevel"] = 1.0 }
                return b
            }
            game["world"] = world
        },
        // v6 → v7 (Phase 10): upkeep per room (created by the simulation's sync on the next
        // step, as new), facilities jobs, a wages ledger category and a poor-services decline
        // reason (count arrays grow by one).
        6: { game in
            guard var world = game["world"] as? [String: Any] else { throw SaveError.corrupt("v6 save without world") }
            if world["upkeep"] == nil { world["upkeep"] = [Any]() }
            if world["facilities"] == nil { world["facilities"] = ["jobs": [Any](), "cleaned": 0, "repaired": 0] as [String: Any] }
            if var ledger = world["ledger"] as? [String: Any] {
                ledger["days"] = (ledger["days"] as? [[String: Any]] ?? []).map { day -> [String: Any] in
                    var d = day
                    let amounts = d["amounts"] as? [Int] ?? []
                    if amounts.count < 9 { d["amounts"] = amounts + [Int](repeating: 0, count: 9 - amounts.count) }
                    return d
                }
                world["ledger"] = ledger
            }
            if var market = world["market"] as? [String: Any] {
                let declined = market["declined"] as? [Int] ?? []
                if declined.count < 6 { market["declined"] = declined + [Int](repeating: 0, count: 6 - declined.count) }
                world["market"] = market
            }
            game["world"] = world
        },
    ]

    private struct Envelope<Game: Codable>: Codable {
        var format: String
        var formatVersion: Int
        var game: Game
    }

    private struct Header: Decodable {
        var format: String?
        var formatVersion: Int?
    }

    static func makeEncoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    static func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    public static func encode(_ save: SaveGame) throws -> Data {
        try makeEncoder().encode(Envelope(format: format, formatVersion: currentVersion, game: save))
    }

    public static func decode(_ data: Data, availablePacks: [ContentPackReference],
                              migrations: [Int: Migration] = SaveCodec.migrations,
                              currentVersion: Int = SaveCodec.currentVersion) throws -> SaveGame {
        guard let header = try? makeDecoder().decode(Header.self, from: data),
              header.format == format, let version = header.formatVersion else { throw SaveError.notASave }
        guard version <= currentVersion else { throw SaveError.newerFormat(found: version, supported: currentVersion) }

        let save: SaveGame
        if version == currentVersion {
            do { save = try makeDecoder().decode(Envelope<SaveGame>.self, from: data).game } catch {
                throw SaveError.corrupt(String(describing: error))
            }
        } else {
            save = try migrateAndDecode(data, from: version, to: currentVersion, migrations: migrations)
        }

        let installed = Set(availablePacks.map(\.id))
        if let missing = save.contentPacks.first(where: { !installed.contains($0.id) }) {
            throw SaveError.missingContentPack(missing.id)
        }
        do { try save.world.validateIntegrity() } catch { throw SaveError.invalidWorld(String(describing: error)) }
        guard save.world.properties.contains(save.activePropertyID) else { throw SaveError.invalidWorld("active property missing") }
        return save
    }

    private static func migrateAndDecode(_ data: Data, from version: Int, to target: Int,
                                         migrations: [Int: Migration]) throws -> SaveGame {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var game = root["game"] as? [String: Any] else { throw SaveError.corrupt("missing game object") }
        var v = version
        while v < target {
            guard let step = migrations[v] else { throw SaveError.noMigration(from: v) }
            do { try step(&game) } catch { throw SaveError.migrationFailed(from: v, reason: String(describing: error)) }
            v += 1
        }
        do {
            let upgraded = try JSONSerialization.data(withJSONObject: game)
            return try makeDecoder().decode(SaveGame.self, from: upgraded)
        } catch {
            throw SaveError.corrupt(String(describing: error))
        }
    }

    /// Reads only the metadata of a save (for save lists) without validating the world.
    public static func peekMetadata(_ data: Data) -> SaveMetadata? {
        struct Peek: Decodable {
            struct Game: Decodable { var metadata: SaveMetadata }
            var format: String
            var game: Game
        }
        guard let peek = try? makeDecoder().decode(Peek.self, from: data), peek.format == format else { return nil }
        return peek.game.metadata
    }
}
