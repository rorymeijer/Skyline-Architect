import Foundation
import SkylineCore

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
    private var cityIndex: [String: Int] = [:]
    private var plotIndex: [String: Int] = [:]
    private var startIndex: [String: Int] = [:]

    public func city(_ id: String) -> CityDefinition? { cityIndex[id].map { orderedCities[$0] } }
    public func plot(_ id: String) -> PlotDefinition? { plotIndex[id].map { orderedPlots[$0] } }
    public func start(_ id: String) -> StartDefinition? { startIndex[id].map { orderedStarts[$0] } }

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
