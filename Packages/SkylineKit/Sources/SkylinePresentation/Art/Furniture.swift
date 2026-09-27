import Foundation
import SkylineCore

/// One primitive of a furniture recipe, in the piece's local meters (origin at the
/// bottom-left, y up, x from the piece's left edge).
public struct FurniturePart: Codable, Hashable, Sendable {
    public enum Shape: String, Codable, Sendable { case rect, ellipse, polygon, line }

    public var shape: Shape
    public var x: Double?
    public var y: Double?
    public var w: Double?
    public var h: Double?
    /// Polygon / line vertices as `[x, y]` pairs.
    public var points: [[Double]]?
    /// Material key from `materials.json`, or `$slot` resolved through the chosen variant.
    public var material: String
    /// If set, the part is a vertical gradient from the material (top) to material × shade (bottom).
    public var shade: Double?
    /// Line width in meters (lines only).
    public var lineWidth: Double?
    public var opacity: Double?
    /// Minimum raster density for this part (small details); defaults to the piece's.
    public var minDetail: Double?

    public init(shape: Shape, x: Double? = nil, y: Double? = nil, w: Double? = nil, h: Double? = nil,
                points: [[Double]]? = nil, material: String, shade: Double? = nil, lineWidth: Double? = nil,
                opacity: Double? = nil, minDetail: Double? = nil) {
        self.shape = shape
        self.x = x
        self.y = y
        self.w = w
        self.h = h
        self.points = points
        self.material = material
        self.shade = shade
        self.lineWidth = lineWidth
        self.opacity = opacity
        self.minDetail = minDetail
    }
}

/// A furniture piece drawn from declarative parts (`furniture.json`). Mods add furniture
/// by adding data; no code is involved.
public struct FurnitureDefinition: Codable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var width: Double
    public var height: Double
    public var parts: [FurniturePart]
    /// Alternative slot → material assignments (e.g. car body colours). One is chosen
    /// deterministically per placed instance.
    public var variants: [[String: String]]?
    /// Default minimum raster density for all parts (furniture is clutter when far away).
    public var minDetail: Double?

    public init(id: String, name: String, width: Double, height: Double, parts: [FurniturePart],
                variants: [[String: String]]? = nil, minDetail: Double? = nil) {
        self.id = id
        self.name = name
        self.width = width
        self.height = height
        self.parts = parts
        self.variants = variants
        self.minDetail = minDetail
    }
}

/// How a room type is furnished (`interiors.json`). Items are placed along the room's
/// width (a side section shows furniture front-on); see `LayoutResolver`.
public struct InteriorLayout: Codable, Hashable, Sendable {
    public enum Anchor: String, Codable, Sendable { case left, right, center }

    public struct Item: Codable, Hashable, Sendable {
        public var furniture: String?
        public var anchor: Anchor?
        /// Distance from the anchor wall (or from the center) in meters.
        public var offset: Double?
        /// Height above the floor (e.g. a monitor on a desk, a picture on the wall).
        public var elevation: Double?
        /// Mirror horizontally.
        public var flip: Bool?
        /// The item is placed only in rooms at least this wide / at most this wide.
        public var minRoomWidth: Double?
        public var maxRoomWidth: Double?
        /// Whether the item occupies floor width that other items may not use (default true).
        public var reserve: Bool?
        /// A group repeated across the free width (e.g. workstations).
        public var `repeat`: RepeatGroup?

        public init(furniture: String? = nil, anchor: Anchor? = nil, offset: Double? = nil, elevation: Double? = nil,
                    flip: Bool? = nil, minRoomWidth: Double? = nil, maxRoomWidth: Double? = nil,
                    reserve: Bool? = nil, repeat: RepeatGroup? = nil) {
            self.furniture = furniture
            self.anchor = anchor
            self.offset = offset
            self.elevation = elevation
            self.flip = flip
            self.minRoomWidth = minRoomWidth
            self.maxRoomWidth = maxRoomWidth
            self.reserve = reserve
            self.repeat = `repeat`
        }
    }

    public struct GroupItem: Codable, Hashable, Sendable {
        public var furniture: String
        public var offset: Double
        public var elevation: Double?
        public var flip: Bool?

        public init(furniture: String, offset: Double, elevation: Double? = nil, flip: Bool? = nil) {
            self.furniture = furniture
            self.offset = offset
            self.elevation = elevation
            self.flip = flip
        }
    }

    public struct RepeatGroup: Codable, Hashable, Sendable {
        /// Distance between consecutive group origins.
        public var spacing: Double
        /// Clearance kept free next to other items and walls.
        public var margin: Double?
        public var items: [GroupItem]

        public init(spacing: Double, margin: Double? = nil, items: [GroupItem]) {
            self.spacing = spacing
            self.margin = margin
            self.items = items
        }
    }

    /// Room definition id this layout furnishes.
    public var room: String
    public var items: [Item]

    public init(room: String, items: [Item]) {
        self.room = room
        self.items = items
    }
}

/// Visual content: materials, furniture recipes and interior layouts.
public struct ArtCatalog: Sendable {
    public let materials: [String: RGBA]
    public let furniture: [String: FurnitureDefinition]
    /// Keyed by room definition id.
    public let layouts: [String: InteriorLayout]

    public init(materials: [String: RGBA], furniture: [FurnitureDefinition], layouts: [InteriorLayout]) {
        self.materials = materials
        var f: [String: FurnitureDefinition] = [:]
        for def in furniture { f[def.id] = def }
        self.furniture = f
        var l: [String: InteriorLayout] = [:]
        for layout in layouts { l[layout.room] = layout }
        self.layouts = l
    }

    public static let empty = ArtCatalog(materials: [:], furniture: [], layouts: [])

    /// Parses `#RRGGBB` or `#RRGGBBAA`.
    public static func parseColor(_ s: String) -> RGBA? {
        var hex = s
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6 || hex.count == 8, let v = UInt64(hex, radix: 16) else { return nil }
        if hex.count == 6 { return RGBA(hex: UInt32(v)) }
        return RGBA(hex: UInt32(v >> 8), alpha: Double(v & 0xFF) / 255)
    }

    /// Problems in a set of definitions (unknown materials/furniture, bad geometry), empty if valid.
    public static func validate(materials: [String: RGBA], furniture: [FurnitureDefinition],
                                layouts: [InteriorLayout]) -> [String] {
        var problems: [String] = []
        let ids = Set(furniture.map(\.id))
        for def in furniture {
            if def.width <= 0 || def.height <= 0 { problems.append("furniture '\(def.id)': non-positive size") }
            let slots = Set((def.variants ?? []).flatMap(\.keys))
            for (i, part) in def.parts.enumerated() {
                let where_ = "furniture '\(def.id)' part \(i)"
                if part.material.hasPrefix("$") {
                    let slot = String(part.material.dropFirst())
                    if !slots.contains(slot) { problems.append("\(where_): slot '\(slot)' has no variants") }
                } else if materials[part.material] == nil {
                    problems.append("\(where_): unknown material '\(part.material)'")
                }
                switch part.shape {
                case .rect, .ellipse:
                    if part.x == nil || part.y == nil || (part.w ?? 0) <= 0 || (part.h ?? 0) <= 0 {
                        problems.append("\(where_): \(part.shape.rawValue) needs x, y, positive w and h")
                    }
                case .polygon, .line:
                    let pts = part.points ?? []
                    if pts.count < (part.shape == .polygon ? 3 : 2) || pts.contains(where: { $0.count != 2 }) {
                        problems.append("\(where_): \(part.shape.rawValue) needs [x, y] points")
                    }
                }
            }
            for variant in def.variants ?? [] {
                for material in variant.values where materials[material] == nil {
                    problems.append("furniture '\(def.id)': variant uses unknown material '\(material)'")
                }
            }
        }
        for layout in layouts {
            for item in layout.items {
                if let f = item.furniture, !ids.contains(f) { problems.append("layout '\(layout.room)': unknown furniture '\(f)'") }
                if item.furniture == nil && item.repeat == nil { problems.append("layout '\(layout.room)': item needs furniture or repeat") }
                if let g = item.repeat {
                    if g.spacing <= 0 { problems.append("layout '\(layout.room)': repeat spacing must be positive") }
                    for gi in g.items where !ids.contains(gi.furniture) {
                        problems.append("layout '\(layout.room)': unknown furniture '\(gi.furniture)'")
                    }
                }
            }
        }
        return problems
    }
}
