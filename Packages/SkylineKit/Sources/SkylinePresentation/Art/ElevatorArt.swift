import Foundation
import SkylineCore

/// Procedural elevator cab, drawn in cab-local meters (0…width × 0…height). Cutaway like the
/// rooms: the lit interior is visible; the car doors slide open from the centre. The shaft
/// itself (rails, landing doors) is static art in `RoomArt`.
public enum ElevatorArt {
    public static let cabHeight = 2.6
    /// Distance between shaft wall and cab on each side (guide rails live there).
    public static let cabInset = 0.45
    /// Door animation is drawn in this many steps (textures are cached per step).
    public static let doorSteps = 4

    /// `outOfService` (Phase E): the cab is dark, doors shut, with a warning band.
    public static func cab(width w: Double, opening: Double, outOfService: Bool = false, palette p: ArtPalette = .standard) -> Drawing {
        var d = Drawing()
        let h = cabHeight
        let frame = p.steel.shaded(0.7)
        // Interior: warm lit back wall, floor, ceiling light, handrail (dark when broken).
        d.verticalGradient(Rect(x: 0, y: 0, width: w, height: h),
                           top: outOfService ? RGBA(hex: 0x4A4640) : RGBA(hex: 0xF3E6C8),
                           bottom: outOfService ? RGBA(hex: 0x36332F) : RGBA(hex: 0xD9C7A0))
        d.fill(Rect(x: 0.05, y: 0, width: w - 0.1, height: 0.08), RGBA(hex: 0x5B5046))
        d.fill(Rect(x: w * 0.25, y: h - 0.2, width: w * 0.5, height: 0.06), RGBA(hex: 0xFFF8E1))
        d.fill(Rect(x: 0.15, y: 0.95, width: w - 0.3, height: 0.04), p.steel.shaded(1.1), minDetail: 8)
        // Car doors, sliding apart from the centre; partly see-through so riders stay visible.
        let panel = (w / 2 - 0.05) * (1 - min(max(opening, 0), 1))
        if panel > 0.01 {
            let door = p.steel.shaded(0.95).withAlpha(0.72)
            d.fill(Rect(x: 0.05, y: 0.08, width: panel, height: h - 0.3), door)
            d.fill(Rect(x: w - 0.05 - panel, y: 0.08, width: panel, height: h - 0.3), door)
        }
        // Frame: sill, roof with crosshead, side posts.
        d.fill(Rect(x: 0, y: -0.12, width: w, height: 0.12), frame)
        d.fill(Rect(x: 0, y: h - 0.1, width: w, height: 0.22), frame)
        d.fill(Rect(x: w / 2 - 0.12, y: h + 0.12, width: 0.24, height: 0.18), frame.shaded(0.8))
        d.fill(Rect(x: 0, y: 0, width: 0.06, height: h), frame)
        d.fill(Rect(x: w - 0.06, y: 0, width: 0.06, height: h), frame)
        if outOfService {
            // Yellow-and-black warning band across the doors.
            let band = Rect(x: 0.1, y: h * 0.45, width: w - 0.2, height: 0.3)
            d.fill(band, RGBA(hex: 0xE0C23A))
            var x = band.minX
            while x < band.maxX - 0.1 {
                d.add(DrawItem(shape: .polygon([Vec2(x, band.minY), Vec2(x + 0.12, band.minY), Vec2(x + 0.27, band.maxY), Vec2(x + 0.15, band.maxY)]),
                               fill: .solid(RGBA(hex: 0x1E1F21))))
                x += 0.3
            }
        }
        return d
    }
}

/// One visible car at a render time.
public struct CarSprite: Hashable, Sendable {
    public var id: RoomID
    /// Cab rectangle in world meters (bottom = car floor).
    public var rect: Rect
    /// Door opening quantized to `ElevatorArt.doorSteps` (0 closed … steps open).
    public var doorStep: Int
    /// Top of the hoistway (the hoist rope runs from the cab up to here).
    public var ropeTop: Double
    /// Broken down (Phase E).
    public var outOfService = false
}

/// Selects and positions visible cars at a (fractional) time. Pure view of simulation state.
public enum ElevatorView {
    public static func visible(world: GameWorld, propertyID: PropertyID, time: Double, visible: Rect, zoom: Double,
                               doorSeconds: (RoomID) -> Double = { _ in 2 }) -> [CarSprite] {
        guard zoom >= PeopleView.minZoom else { return [] }
        let grid = world.grid
        let buildings = Set(world.buildings(on: propertyID).map(\.id))
        var sprites: [CarSprite] = []
        for car in world.elevators where buildings.contains(car.buildingID) {
            guard let shaft = world.rooms[car.id] else { continue }
            let x0 = grid.x(ofColumn: shaft.columns.start) + ElevatorArt.cabInset
            let x1 = grid.x(ofColumn: shaft.columns.end) - ElevatorArt.cabInset
            let y = ElevatorMotion.y(of: car, at: time, grid: grid)
            let rect = Rect(minX: x0, minY: y, maxX: x1, maxY: y + ElevatorArt.cabHeight)
            let ropeTop = grid.y(ofFloor: shaft.floors.highest + 1) - grid.slabThickness - 0.3
            guard rect.intersects(visible) || Rect(minX: x0, minY: y, maxX: x1, maxY: ropeTop).intersects(visible) else { continue }
            let opening = ElevatorMotion.doorOpening(of: car, at: time, doorSeconds: doorSeconds(car.id))
            sprites.append(CarSprite(id: car.id, rect: rect, doorStep: Int((opening * Double(ElevatorArt.doorSteps)).rounded()),
                                     ropeTop: ropeTop, outOfService: car.isOutOfService))
        }
        return sprites
    }
}
