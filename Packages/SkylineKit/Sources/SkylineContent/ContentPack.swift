import Foundation
import SkylineCore
import SkylinePresentation
import SkylineSimulation

/// One content pack as read from disk, before validation (Phase 17). Packs are laid over
/// each other (`overlay`) and the result is validated as a whole (`ContentLibrary.build`).
public struct ContentPack: Sendable {
    public var manifest: ContentPackManifest
    var cities: [CityDefinition] = []
    var plots: [PlotDefinition] = []
    var starts: [StartDefinition] = []
    var rooms: [RoomSpec] = []
    var blueprints: [Blueprint] = []
    var furniture: [FurnitureDefinition] = []
    var interiors: [InteriorLayout] = []
    var schedules: [Schedule] = []
    var elevators: [ElevatorSpec] = []
    var tenants: [TenantType] = []
    var scenarios: [ScenarioDefinition] = []
    var materials: [String: String] = [:]
    var buildRules: BuildRules?
    var names: NamePool?
    var economy: EconomyRules?
    var facilities: FacilitiesRules?
    var progression: ProgressionDefinition?
    var weather: WeatherRules?
    var events: EventRules?

    /// Every definition kind a manifest may list.
    public static let kinds: Set<String> = ["cities", "plots", "starts", "rooms", "buildRules", "blueprints", "materials", "furniture",
                                            "interiors", "schedules", "names", "elevators", "tenants", "economy", "facilities",
                                            "progression", "weather", "events", "scenarios"]

    /// Reads and decodes a pack folder. Throws on an unreadable manifest, an unsupported
    /// format, an unknown kind or invalid JSON — never on content rules (see `build`).
    public static func read(at url: URL) throws -> ContentPack {
        let manifest: ContentPackManifest = try decode(url.appendingPathComponent("pack.json"), pack: url.lastPathComponent, file: "pack.json")
        guard manifest.formatVersion == ContentPackManifest.supportedFormatVersion else {
            throw ContentError(pack: manifest.id, file: "pack.json",
                               message: "Unsupported formatVersion \(manifest.formatVersion) (engine supports \(ContentPackManifest.supportedFormatVersion))")
        }
        if let unknown = manifest.files.keys.sorted().first(where: { !kinds.contains($0) }) {
            throw ContentError(pack: manifest.id, file: "pack.json", message: "Unknown definition kind '\(unknown)'")
        }
        func load<T: Decodable>(_ kind: String) throws -> T? {
            guard let file = manifest.files[kind] else { return nil }
            return try decode(url.appendingPathComponent(file), pack: manifest.id, file: file)
        }
        var p = ContentPack(manifest: manifest)
        p.manifest.contentHash = try contentHash(of: url, manifest: manifest)
        p.cities = try load("cities") ?? []
        p.plots = try load("plots") ?? []
        p.starts = try load("starts") ?? []
        p.rooms = try load("rooms") ?? []
        p.blueprints = try load("blueprints") ?? []
        p.furniture = try load("furniture") ?? []
        p.interiors = try load("interiors") ?? []
        p.schedules = try load("schedules") ?? []
        p.elevators = try load("elevators") ?? []
        p.tenants = try load("tenants") ?? []
        p.scenarios = try load("scenarios") ?? []
        p.materials = try load("materials") ?? [:]
        p.buildRules = try load("buildRules")
        p.names = try load("names")
        p.economy = try load("economy")
        p.facilities = try load("facilities")
        p.progression = try load("progression")
        p.weather = try load("weather")
        p.events = try load("events")
        return p
    }

    /// FNV-1a (64 bit) over `pack.json` and every listed file, in kind order: stable across
    /// platforms and runs, and enough to notice a changed pack (not a security measure).
    static func contentHash(of url: URL, manifest: ContentPackManifest) throws -> String {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        func mix(_ bytes: Data) {
            for b in bytes {
                hash ^= UInt64(b)
                hash = hash &* 0x0000_0100_0000_01B3
            }
        }
        let files = ["pack.json"] + manifest.files.keys.sorted().compactMap { manifest.files[$0] }
        for file in files {
            mix(Data(file.utf8))
            do { mix(try Data(contentsOf: url.appendingPathComponent(file))) } catch {
                throw ContentError(pack: manifest.id, file: file, message: "Cannot read file: \(error.localizedDescription)")
            }
        }
        return String(hash, radix: 16)
    }

    static func decode<T: Decodable>(_ url: URL, pack: String, file: String) throws -> T {
        let data: Data
        do { data = try Data(contentsOf: url) } catch {
            throw ContentError(pack: pack, file: file, message: "Cannot read file: \(error.localizedDescription)")
        }
        do { return try JSONDecoder().decode(T.self, from: data) } catch {
            throw ContentError(pack: pack, file: file, message: "Invalid JSON: \(error)")
        }
    }

    // MARK: Overlay

    /// What a pack changed when laid over the others ("tenant 'call-centre'").
    public struct Changes: Equatable, Sendable {
        public var added: [String] = []
        public var replaced: [String] = []
    }

    /// Lays `mod` over this pack. Entries of list kinds replace the entry with the same id
    /// in place (keeping its position) or are appended; single-file kinds (rules, economy,
    /// progression, …) replace the whole file; materials merge per key. The manifest stays
    /// this pack's.
    public mutating func overlay(_ mod: ContentPack) -> Changes {
        var c = Changes()
        func merge<T>(_ list: inout [T], _ add: [T], kind: String, id: (T) -> String) {
            for item in add {
                if let i = list.firstIndex(where: { id($0) == id(item) }) {
                    list[i] = item
                    c.replaced.append("\(kind) '\(id(item))'")
                } else {
                    list.append(item)
                    c.added.append("\(kind) '\(id(item))'")
                }
            }
        }
        merge(&cities, mod.cities, kind: "city", id: \.id)
        merge(&plots, mod.plots, kind: "plot", id: \.id)
        merge(&starts, mod.starts, kind: "start", id: \.id)
        merge(&rooms, mod.rooms, kind: "room", id: \.id)
        merge(&blueprints, mod.blueprints, kind: "blueprint", id: \.id)
        merge(&furniture, mod.furniture, kind: "furniture", id: \.id)
        merge(&interiors, mod.interiors, kind: "interior", id: \.room)
        merge(&schedules, mod.schedules, kind: "schedule", id: \.id)
        merge(&elevators, mod.elevators, kind: "elevator", id: \.room)
        merge(&tenants, mod.tenants, kind: "tenant", id: \.id)
        merge(&scenarios, mod.scenarios, kind: "scenario", id: \.id)
        for key in mod.materials.keys.sorted() {
            c.append(materials[key] == nil ? \.added : \.replaced, "material '\(key)'")
            materials[key] = mod.materials[key]
        }
        func replace<T>(_ value: inout T?, _ new: T?, kind: String) {
            guard let new else { return }
            c.append(value == nil ? \.added : \.replaced, kind)
            value = new
        }
        replace(&buildRules, mod.buildRules, kind: "build rules")
        replace(&names, mod.names, kind: "names")
        replace(&economy, mod.economy, kind: "economy")
        replace(&facilities, mod.facilities, kind: "facilities")
        replace(&progression, mod.progression, kind: "progression")
        replace(&weather, mod.weather, kind: "weather")
        replace(&events, mod.events, kind: "events")
        return c
    }
}

private extension ContentPack.Changes {
    mutating func append(_ list: WritableKeyPath<Self, [String]>, _ entry: String) { self[keyPath: list].append(entry) }
}
