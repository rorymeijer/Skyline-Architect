import Foundation
import SkylineCore
import SkylinePresentation

public struct ContentError: Error, CustomStringConvertible, Equatable {
    public var pack: String
    public var file: String
    public var message: String

    public init(pack: String, file: String, message: String) {
        self.pack = pack
        self.file = file
        self.message = message
    }

    public var description: String { "[\(pack)/\(file)] \(message)" }
}

/// All loaded, validated content definitions, keyed by id. Lookup order of the
/// `ordered*` arrays is file order, so iteration is deterministic.
public struct ContentLibrary: Sendable {
    public private(set) var manifest: ContentPackManifest
    public private(set) var orderedCities: [CityDefinition] = []
    public private(set) var orderedPlots: [PlotDefinition] = []
    public private(set) var orderedStarts: [StartDefinition] = []
    public private(set) var orderedRooms: [RoomSpec] = []
    public private(set) var orderedBlueprints: [Blueprint] = []
    public private(set) var artCatalog = ArtCatalog.empty
    public private(set) var buildRules = BuildRules(slabCostPerModule: 0, basementSlabCostPerModule: 0, maxCantileverModules: 0, demolitionRefund: 0)
    private var cityIndex: [String: Int] = [:]
    private var plotIndex: [String: Int] = [:]
    private var startIndex: [String: Int] = [:]

    public func city(_ id: String) -> CityDefinition? { cityIndex[id].map { orderedCities[$0] } }
    public func plot(_ id: String) -> PlotDefinition? { plotIndex[id].map { orderedPlots[$0] } }
    public func start(_ id: String) -> StartDefinition? { startIndex[id].map { orderedStarts[$0] } }
    public func blueprint(_ id: String) -> Blueprint? { orderedBlueprints.first { $0.id == id } }

    /// Construction rules and room specs for the engine.
    public var buildCatalog: BuildCatalog { BuildCatalog(rules: buildRules, specs: orderedRooms) }

    /// Identity of this pack, stored in saves.
    public var packReference: (id: String, version: String) { (manifest.id, manifest.version) }

    /// Loads the bundled base pack.
    public static func loadBase() throws -> ContentLibrary {
        try load(packAt: BaseContent.packURL)
    }

    /// Loads and validates a pack folder. Any error rejects the whole pack.
    public static func load(packAt url: URL) throws -> ContentLibrary {
        let manifest: ContentPackManifest = try decode(url.appendingPathComponent("pack.json"), pack: url.lastPathComponent, file: "pack.json")
        guard manifest.formatVersion == ContentPackManifest.supportedFormatVersion else {
            throw ContentError(pack: manifest.id, file: "pack.json",
                               message: "Unsupported formatVersion \(manifest.formatVersion) (engine supports \(ContentPackManifest.supportedFormatVersion))")
        }
        func list<T: Decodable>(_ kind: String) throws -> [T] {
            guard let file = manifest.files[kind] else { return [] }
            return try decode(url.appendingPathComponent(file), pack: manifest.id, file: file)
        }
        var library = ContentLibrary(manifest: manifest)
        try library.register(cities: list("cities"), plots: list("plots"), starts: list("starts"))
        if let file = manifest.files["buildRules"] {
            let rules: BuildRules = try decode(url.appendingPathComponent(file), pack: manifest.id, file: file)
            try library.register(rules: rules)
        }
        try library.register(rooms: list("rooms"), blueprints: list("blueprints"))
        var materials: [String: String] = [:]
        if let file = manifest.files["materials"] {
            materials = try decode(url.appendingPathComponent(file), pack: manifest.id, file: file)
        }
        try library.register(materials: materials, furniture: list("furniture"), interiors: list("interiors"))
        return library
    }

    init(manifest: ContentPackManifest) {
        self.manifest = manifest
    }

    /// Registers definitions and validates ids, references and value ranges.
    mutating func register(cities: [CityDefinition], plots: [PlotDefinition], starts: [StartDefinition]) throws {
        let pack = manifest.id
        func fail(_ file: String, _ message: String) -> ContentError {
            ContentError(pack: pack, file: manifest.files[file] ?? file, message: message)
        }
        for c in cities {
            guard cityIndex[c.id] == nil else { throw fail("cities", "Duplicate city id '\(c.id)'") }
            guard !c.geology.isEmpty else { throw fail("cities", "City '\(c.id)' has no geology") }
            guard c.geology.allSatisfy({ $0.thickness > 0 }) else {
                throw fail("cities", "City '\(c.id)' has a stratum with non-positive thickness")
            }
            cityIndex[c.id] = orderedCities.count
            orderedCities.append(c)
        }
        for p in plots {
            guard plotIndex[p.id] == nil else { throw fail("plots", "Duplicate plot id '\(p.id)'") }
            guard cityIndex[p.cityID] != nil else { throw fail("plots", "Plot '\(p.id)' references unknown city '\(p.cityID)'") }
            guard p.frontageModules > 0, p.maxBasementFloors >= 0, p.siteMarginModules >= 0 else {
                throw fail("plots", "Plot '\(p.id)' has invalid dimensions")
            }
            plotIndex[p.id] = orderedPlots.count
            orderedPlots.append(p)
        }
        for s in starts {
            guard startIndex[s.id] == nil else { throw fail("starts", "Duplicate start id '\(s.id)'") }
            guard cityIndex[s.cityID] != nil else { throw fail("starts", "Start '\(s.id)' references unknown city '\(s.cityID)'") }
            guard let plot = plotIndex[s.plotID].map({ orderedPlots[$0] }) else {
                throw fail("starts", "Start '\(s.id)' references unknown plot '\(s.plotID)'")
            }
            guard plot.cityID == s.cityID else {
                throw fail("starts", "Start '\(s.id)': plot '\(plot.id)' is in city '\(plot.cityID)', not '\(s.cityID)'")
            }
            startIndex[s.id] = orderedStarts.count
            orderedStarts.append(s)
        }
    }

    mutating func register(rules: BuildRules) throws {
        guard rules.slabCostPerModule >= 0, rules.basementSlabCostPerModule >= 0, rules.maxCantileverModules >= 0,
              (0...1).contains(rules.demolitionRefund) else {
            throw ContentError(pack: manifest.id, file: manifest.files["buildRules"] ?? "buildRules", message: "Build rules out of range")
        }
        buildRules = rules
    }

    mutating func register(rooms: [RoomSpec], blueprints: [Blueprint]) throws {
        let file = manifest.files["rooms"] ?? "rooms"
        var ids = Set(orderedRooms.map(\.id))
        for r in rooms {
            func fail(_ m: String) -> ContentError { ContentError(pack: manifest.id, file: file, message: "Room '\(r.id)': \(m)") }
            guard ids.insert(r.id).inserted else { throw fail("duplicate id") }
            guard r.minWidth >= 1, r.maxWidth >= r.minWidth else { throw fail("invalid width range") }
            guard r.minFloors >= 1, r.maxFloors >= r.minFloors else { throw fail("invalid floor range") }
            guard r.kind == .room || r.minFloors >= 2 else { throw fail("shafts must span at least 2 floors") }
            guard r.costPerModule >= 0 else { throw fail("negative cost") }
            if let lo = r.lowestLevel, let hi = r.highestLevel, lo > hi { throw fail("lowestLevel above highestLevel") }
            orderedRooms.append(r)
        }
        let bpFile = manifest.files["blueprints"] ?? "blueprints"
        for bp in blueprints {
            func fail(_ m: String) -> ContentError { ContentError(pack: manifest.id, file: bpFile, message: "Blueprint '\(bp.id)': \(m)") }
            guard !orderedBlueprints.contains(where: { $0.id == bp.id }) else { throw fail("duplicate id") }
            for (i, step) in bp.steps.enumerated() {
                guard (step.floor == nil) != (step.room == nil) else { throw fail("step \(i) must have exactly one of floor/room") }
                if let r = step.room, !ids.contains(r.definition) { throw fail("step \(i) uses unknown room '\(r.definition)'") }
            }
            orderedBlueprints.append(bp)
        }
    }

    /// Registers visual content; every material, furniture and room reference must resolve.
    mutating func register(materials raw: [String: String], furniture: [FurnitureDefinition], interiors: [InteriorLayout]) throws {
        var materials: [String: RGBA] = [:]
        for key in raw.keys.sorted() {
            guard let color = ArtCatalog.parseColor(raw[key]!) else {
                throw ContentError(pack: manifest.id, file: manifest.files["materials"] ?? "materials", message: "Material '\(key)': invalid colour '\(raw[key]!)'")
            }
            materials[key] = color
        }
        var problems = ArtCatalog.validate(materials: materials, furniture: furniture, layouts: interiors)
        var seen = Set<String>()
        for def in furniture where !seen.insert(def.id).inserted { problems.append("duplicate furniture id '\(def.id)'") }
        let roomIDs = Set(orderedRooms.map(\.id))
        for layout in interiors where !roomIDs.contains(layout.room) { problems.append("layout for unknown room '\(layout.room)'") }
        if let first = problems.first {
            throw ContentError(pack: manifest.id, file: "furniture/interiors", message: problems.count == 1 ? first : "\(first) (+\(problems.count - 1) more)")
        }
        artCatalog = ArtCatalog(materials: materials, furniture: furniture, layouts: interiors)
    }

    private static func decode<T: Decodable>(_ url: URL, pack: String, file: String) throws -> T {
        let data: Data
        do { data = try Data(contentsOf: url) } catch {
            throw ContentError(pack: pack, file: file, message: "Cannot read file: \(error.localizedDescription)")
        }
        do { return try JSONDecoder().decode(T.self, from: data) } catch {
            throw ContentError(pack: pack, file: file, message: "Invalid JSON: \(error)")
        }
    }
}
