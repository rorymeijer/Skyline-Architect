import Foundation
import SkylineCore

/// Interior finishes of placed rooms and shafts, keyed by the definition's `appearance`.
/// Phase 2 draws *shells with finishes* (walls, floor finish, ceiling, lights, doors,
/// stairs, hoistways); furniture and occupants arrive in Phase 3/4.
enum RoomArt {
    static let partitionThickness = 0.12

    static func draw(into d: inout Drawing, room: Room, appearance: String, layout: InteriorLayout?, art: ArtCatalog,
                     building: Building, grid: GridSpec, palette p: ArtPalette) {
        let x0 = grid.x(ofColumn: room.columns.start), x1 = grid.x(ofColumn: room.columns.end)
        let f = p.finishes(appearance)
        var rng = SeededRandom(seed: UInt64(room.id.raw), stream: 0x2A0)

        switch appearance {
        case "stairs":
            stairs(into: &d, room: room, x0: x0, x1: x1, grid: grid, palette: p, rng: &rng)
        case "elevatorShaft":
            hoistway(into: &d, room: room, x0: x0, x1: x1, grid: grid, palette: p)
        default:
            // One storey at a time so multi-storey rooms still show their levels.
            for level in room.floors.lowest...room.floors.highest {
                let fy = grid.y(ofFloor: level), cy = grid.y(ofFloor: level + 1) - grid.slabThickness
                storey(into: &d, appearance: appearance, rect: Rect(minX: x0, minY: fy, maxX: x1, maxY: cy),
                       finishes: f, palette: p, drawDoor: layout == nil, rng: &rng)
                if let layout {
                    let (ix0, ix1) = innerSpan(room: room, level: level, building: building, x0: x0, x1: x1)
                    let placements = LayoutResolver.resolve(layout, catalog: art, x0: ix0, x1: ix1, floorY: fy + 0.08,
                                                            seed: UInt64(room.id.raw) &* 31 &+ UInt64(bitPattern: Int64(level)))
                    for placed in placements { FurnitureArt.draw(into: &d, placed, catalog: art) }
                }
            }
        }

        // Partitions at the room ends (cut gypsum walls), unless at a plate edge where the
        // façade or retaining wall closes the room.
        for level in room.floors.lowest...room.floors.highest {
            guard let plate = building.plate(at: level) else { continue }
            let fy = grid.y(ofFloor: level), cy = grid.y(ofFloor: level + 1) - grid.slabThickness
            if room.columns.start > plate.span.start {
                d.fill(Rect(minX: x0 - partitionThickness / 2, minY: fy, maxX: x0 + partitionThickness / 2, maxY: cy), p.partition)
            }
            if room.columns.end < plate.span.end {
                d.fill(Rect(minX: x1 - partitionThickness / 2, minY: fy, maxX: x1 + partitionThickness / 2, maxY: cy), p.partition)
            }
        }
    }

    /// Usable width inside partitions, façades or retaining walls.
    static func innerSpan(room: Room, level: Int, building: Building, x0: Double, x1: Double) -> (Double, Double) {
        guard let plate = building.plate(at: level) else { return (x0, x1) }
        let edge = level >= 0 ? BuildingArt.facadeThickness : Foundation.retainingWallThickness
        let left = room.columns.start == plate.span.start ? edge : partitionThickness / 2
        let right = room.columns.end == plate.span.end ? edge : partitionThickness / 2
        return (x0 + left, x1 - right)
    }

    private static func storey(into d: inout Drawing, appearance: String, rect r: Rect,
                               finishes f: (wall: RGBA, floor: RGBA, ceiling: RGBA), palette p: ArtPalette,
                               drawDoor: Bool, rng: inout SeededRandom) {
        // Back wall, floor finish, ceiling band, contact shading.
        d.verticalGradient(r, top: f.wall.shaded(0.96), bottom: f.wall.shaded(1.02))
        d.fill(Rect(minX: r.minX, minY: r.minY, maxX: r.maxX, maxY: r.minY + 0.08), f.floor)
        d.fill(Rect(minX: r.minX, minY: r.minY + 0.08, maxX: r.maxX, maxY: r.minY + 0.18), f.floor.shaded(0.8).withAlpha(0.7), minDetail: 8)
        let ceilingBand = appearance == "parking" || appearance == "mechanical" ? 0.0 : 0.3
        if ceilingBand > 0 {
            d.fill(Rect(minX: r.minX, minY: r.maxY - ceilingBand, maxX: r.maxX, maxY: r.maxY), f.ceiling)
        }
        d.verticalGradient(Rect(minX: r.minX, minY: r.maxY - ceilingBand - 0.5, maxX: r.maxX, maxY: r.maxY - ceilingBand),
                           top: RGBA(0, 0, 0, 0.14), bottom: RGBA(0, 0, 0, 0))

        switch appearance {
        case "office":
            lights(into: &d, r, y: r.maxY - ceilingBand, spacing: 1.8, width: 0.9, palette: p)
            // Cable tray / window-band reflection line on the back wall.
            d.fill(Rect(minX: r.minX, minY: r.minY + 1.0, maxX: r.maxX, maxY: r.minY + 1.03), f.wall.shaded(0.85), minDetail: 14)
            if drawDoor { door(into: &d, x: r.minX + 0.6, floorY: r.minY + 0.08, palette: p, glazed: true) }
        case "apartment":
            lights(into: &d, r, y: r.maxY - ceilingBand, spacing: 3.2, width: 0.35, palette: p)
            // Skirting board and a picture rail.
            d.fill(Rect(minX: r.minX, minY: r.minY + 0.08, maxX: r.maxX, maxY: r.minY + 0.2), p.partition, minDetail: 10)
            d.fill(Rect(minX: r.minX, minY: r.maxY - ceilingBand - 0.35, maxX: r.maxX, maxY: r.maxY - ceilingBand - 0.32), p.partition, minDetail: 14)
            if drawDoor { door(into: &d, x: r.minX + 0.5, floorY: r.minY + 0.08, palette: p, glazed: false) }
        case "lobby":
            // Stone panel joints and a warm light line.
            var x = r.minX + 1.2
            while x < r.maxX - 0.2 {
                d.fill(Rect(minX: x, minY: r.minY + 0.18, maxX: x + 0.015, maxY: r.maxY - ceilingBand), f.wall.shaded(0.85), minDetail: 10)
                x += 1.2
            }
            d.fill(Rect(minX: r.minX, minY: r.minY + 1.4, maxX: r.maxX, maxY: r.minY + 1.42), f.wall.shaded(0.85), minDetail: 10)
            lights(into: &d, r, y: r.maxY - ceilingBand, spacing: 1.2, width: 0.25, palette: p)
        case "corridor":
            lights(into: &d, r, y: r.maxY - ceilingBand, spacing: 2.4, width: 0.5, palette: p)
            d.fill(Rect(minX: r.minX, minY: r.minY + 0.9, maxX: r.maxX, maxY: r.minY + 0.94), f.wall.shaded(0.88), minDetail: 12)
        case "mechanical":
            // Placeholder plant: boxes with vents and insulated pipe runs (programmer art).
            var x = r.minX + 0.4
            while x + 1.6 < r.maxX {
                let h = rng.double(in: 1.4..<2.4)
                let box = Rect(minX: x, minY: r.minY + 0.08, maxX: x + 1.5, maxY: r.minY + 0.08 + h)
                d.verticalGradient(box, top: p.steel.shaded(1.05), bottom: p.steel.shaded(0.85))
                d.outline(box, p.mullion, width: 0.02, minDetail: 10)
                var vy = box.maxY - 0.3
                while vy > box.minY + 0.3 {
                    d.fill(Rect(minX: box.minX + 0.2, minY: vy, maxX: box.maxX - 0.2, maxY: vy + 0.04), p.mullion.withAlpha(0.6), minDetail: 20)
                    vy -= 0.12
                }
                x += 2.1
            }
            for (i, color) in [RGBA(hex: 0x3D7EA6), RGBA(hex: 0xB8453A), RGBA(hex: 0x6C8F4E)].enumerated() {
                let py = r.maxY - 0.35 - Double(i) * 0.28
                d.fill(Rect(minX: r.minX, minY: py, maxX: r.maxX, maxY: py + 0.16), color.shaded(0.9), minDetail: 6)
            }
        case "parking":
            // Painted bay markings on the slab edge and wheel stops.
            var x = r.minX + 0.2
            while x < r.maxX {
                d.fill(Rect(minX: x, minY: r.minY + 0.08, maxX: x + 1.2, maxY: r.minY + 0.1), RGBA(hex: 0xE0C23A), minDetail: 8)
                x += 2.5
            }
            d.fill(Rect(minX: r.minX, minY: r.minY + 0.9, maxX: r.maxX, maxY: r.minY + 1.2), RGBA(hex: 0xE0C23A).withAlpha(0.35), minDetail: 6)
            lights(into: &d, r, y: r.maxY, spacing: 3.0, width: 1.2, palette: p)
        default:
            break
        }
    }

    private static func lights(into d: inout Drawing, _ r: Rect, y: Double, spacing: Double, width: Double, palette p: ArtPalette) {
        var x = r.minX + spacing / 2
        while x + width / 2 < r.maxX {
            d.fill(Rect(minX: x - width / 2, minY: y - 0.05, maxX: x + width / 2, maxY: y), p.ceilingLight, minDetail: 6)
            // Soft light spill on the wall below.
            d.verticalGradient(Rect(minX: x - width, minY: y - 1.2, maxX: x + width, maxY: y - 0.05),
                               top: p.ceilingLight.withAlpha(0.25), bottom: p.ceilingLight.withAlpha(0), minDetail: 10)
            x += spacing
        }
    }

    private static func door(into d: inout Drawing, x: Double, floorY: Double, palette p: ArtPalette, glazed: Bool) {
        let leaf = Rect(minX: x, minY: floorY, maxX: x + 0.9, maxY: floorY + 2.1)
        d.fill(leaf.insetBy(dx: -0.06, dy: 0).union(Rect(minX: leaf.minX - 0.06, minY: leaf.minY, maxX: leaf.maxX + 0.06, maxY: leaf.maxY + 0.06)), p.doorFrame, minDetail: 5)
        d.verticalGradient(leaf, top: p.door.shaded(1.08), bottom: p.door.shaded(0.92), minDetail: 5)
        if glazed {
            d.fill(Rect(minX: leaf.minX + 0.15, minY: leaf.minY + 0.9, maxX: leaf.maxX - 0.15, maxY: leaf.maxY - 0.15), p.glazing.shaded(0.9), minDetail: 10)
        }
        d.fill(Rect(minX: leaf.maxX - 0.18, minY: leaf.minY + 1.0, maxX: leaf.maxX - 0.08, maxY: leaf.minY + 1.04), p.steel, minDetail: 20)
    }

    /// Stairwell: concrete shaft with two flights and a half landing per storey.
    private static func stairs(into d: inout Drawing, room: Room, x0: Double, x1: Double, grid: GridSpec,
                               palette p: ArtPalette, rng: inout SeededRandom) {
        let f = p.finishes("stairs")
        let whole = Rect(minX: x0, minY: grid.y(ofFloor: room.floors.lowest), maxX: x1, maxY: grid.y(ofFloor: room.floors.highest + 1) - grid.slabThickness)
        d.verticalGradient(whole, top: f.wall.shaded(0.9), bottom: f.wall.shaded(1.0))
        let landing = 1.1
        for level in room.floors.lowest...room.floors.highest {
            let y0 = grid.y(ofFloor: level)
            let h = grid.floorHeight
            let mid = y0 + h / 2
            // Flight 1: left landing → right half landing.  Flight 2: back to the left.
            flight(into: &d, from: Vec2(x0 + landing, y0), to: Vec2(x1 - landing, mid), palette: p)
            flight(into: &d, from: Vec2(x1 - landing, mid), to: Vec2(x0 + landing, y0 + h), palette: p)
            // Half landing slab at the right, floor landing at the left.
            FoundationArt.cutConcrete(into: &d, rect: Rect(minX: x1 - landing, minY: mid - 0.2, maxX: x1, maxY: mid), palette: p, rng: &rng)
            if level > room.floors.lowest {
                d.fill(Rect(minX: x0, minY: y0 - 0.2, maxX: x0 + landing, maxY: y0), p.concreteCut)
            }
            // Handrail following flight 1.
            d.line([Vec2(x0 + landing, y0 + 0.9), Vec2(x1 - landing, mid + 0.9)], p.steel, width: 0.04, minDetail: 8)
        }
        // Fire-rated shaft walls.
        d.fill(Rect(minX: x0 - 0.1, minY: whole.minY, maxX: x0 + 0.1, maxY: whole.maxY), p.concreteCut.shaded(0.95))
        d.fill(Rect(minX: x1 - 0.1, minY: whole.minY, maxX: x1 + 0.1, maxY: whole.maxY), p.concreteCut.shaded(0.95))
    }

    private static func flight(into d: inout Drawing, from a: Vec2, to b: Vec2, palette p: ArtPalette) {
        let steps = 11
        let run = (b.x - a.x) / Double(steps), rise = (b.y - a.y) / Double(steps)
        var pts: [Vec2] = [a]
        for i in 0..<steps {
            let base = a + Vec2(run * Double(i), rise * Double(i))
            pts.append(base + Vec2(0, rise))
            pts.append(base + Vec2(run, rise))
        }
        // Waist slab underneath the treads.
        let waist = 0.18
        pts.append(b + Vec2(0, -waist))
        pts.append(a + Vec2(0, -waist))
        d.add(DrawItem(shape: .polygon(pts), fill: .solid(p.concreteCut.shaded(1.05)), stroke: Stroke(p.concreteEdge, width: 0.03)))
    }

    /// Elevator hoistway: dark shaft, guide rails and landing doors at each floor.
    /// (Cars arrive with Phase 6.)
    private static func hoistway(into d: inout Drawing, room: Room, x0: Double, x1: Double, grid: GridSpec, palette p: ArtPalette) {
        let f = p.finishes("elevatorShaft")
        let bottom = grid.y(ofFloor: room.floors.lowest)
        let top = grid.y(ofFloor: room.floors.highest + 1) - grid.slabThickness
        // Pit below the lowest landing.
        let shaft = Rect(minX: x0, minY: bottom - 1.2, maxX: x1, maxY: top)
        d.horizontalGradient(shaft, stops: [GradientStop(0, f.wall.shaded(0.8)), GradientStop(0.5, f.wall.shaded(1.1)), GradientStop(1, f.wall.shaded(0.8))])
        for rx in [x0 + 0.35, x1 - 0.35] {
            d.fill(Rect(minX: rx - 0.04, minY: shaft.minY, maxX: rx + 0.04, maxY: shaft.maxY), p.steel.shaded(0.9), minDetail: 4)
        }
        let cx = (x0 + x1) / 2
        for level in room.floors.lowest...room.floors.highest {
            let y = grid.y(ofFloor: level)
            let doorRect = Rect(minX: cx - 0.55, minY: y, maxX: cx + 0.55, maxY: y + 2.2)
            d.fill(doorRect.insetBy(dx: -0.08, dy: 0).union(Rect(minX: doorRect.minX - 0.08, minY: y, maxX: doorRect.maxX + 0.08, maxY: doorRect.maxY + 0.1)), p.doorFrame, minDetail: 4)
            d.horizontalGradient(doorRect, stops: [GradientStop(0, p.steel.shaded(0.85)), GradientStop(0.5, p.steel.shaded(1.1)), GradientStop(1, p.steel.shaded(0.85))], minDetail: 4)
            d.fill(Rect(minX: cx - 0.01, minY: y, maxX: cx + 0.01, maxY: y + 2.2), p.mullion, minDetail: 12)
            // Landing sill and hall-call indicator.
            d.fill(Rect(minX: doorRect.minX - 0.1, minY: y - 0.03, maxX: doorRect.maxX + 0.1, maxY: y), p.steel, minDetail: 8)
            d.fill(Rect(minX: cx - 0.06, minY: y + 2.45, maxX: cx + 0.06, maxY: y + 2.55), RGBA(hex: 0xF4D35E), minDetail: 20)
        }
        // Overhead sheave beam.
        d.fill(Rect(minX: x0, minY: top - 0.3, maxX: x1, maxY: top), p.steel.shaded(0.7))
    }
}
