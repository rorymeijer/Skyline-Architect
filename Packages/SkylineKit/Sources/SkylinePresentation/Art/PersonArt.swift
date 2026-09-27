import Foundation
import SkylineCore

/// Visual identity of a person, derived deterministically from traits and role.
public struct PersonLook: Hashable, Sendable {
    public var skin: Int
    public var hair: Int
    public var top: Int
    public var bottom: Int
    public var business: Bool
    /// Staff wear coveralls in their trade's colour (0 none, 1 janitor, 2 technician).
    public var uniform: Int

    public init(traits: UInt32, role: PersonRole) {
        var rng = SeededRandom(seed: UInt64(traits), stream: 0x100C)
        skin = rng.int(in: 0..<PersonArt.skins.count)
        hair = rng.int(in: 0..<PersonArt.hairs.count)
        business = role == .worker
        uniform = role == .janitor ? 1 : role == .technician ? 2 : 0
        top = rng.int(in: 0..<(business ? PersonArt.businessTops.count : PersonArt.casualTops.count))
        bottom = rng.int(in: 0..<PersonArt.bottoms.count)
    }

    /// Stable cache key for textures.
    public var key: String { "\(skin)-\(hair)-\(top)-\(bottom)-\(business ? 1 : 0)-\(uniform)" }
}

public enum PersonPose: Int, Hashable, Sendable {
    case standing, walking
}

/// Procedural side-view person figures (programmer art — see ASSET_REQUIREMENTS.md §1).
/// Drawn facing right in local meters, feet at the origin; 4-frame walk cycle.
public enum PersonArt {
    public static let height = 1.75
    public static let width = 0.6
    public static let walkFrames = 4

    static let skins = [RGBA(hex: 0xF1C9A5), RGBA(hex: 0xD9A57A), RGBA(hex: 0xA86F48), RGBA(hex: 0x6B4429)]
    static let hairs = [RGBA(hex: 0x2B211B), RGBA(hex: 0x5A3A22), RGBA(hex: 0x9A6B3A), RGBA(hex: 0xC8B28A), RGBA(hex: 0x8C8C8C)]
    static let businessTops = [RGBA(hex: 0x2E3A4B), RGBA(hex: 0x3B3F45), RGBA(hex: 0x5B6C7F), RGBA(hex: 0xE9ECEF), RGBA(hex: 0x6A4F3B)]
    static let casualTops = [RGBA(hex: 0xB8453A), RGBA(hex: 0x3F7CAC), RGBA(hex: 0x6C8F4E), RGBA(hex: 0xE0C23A), RGBA(hex: 0x8E6CA8),
                             RGBA(hex: 0xD98E48), RGBA(hex: 0xEDEDED), RGBA(hex: 0x3A3A3A)]
    /// Coveralls: janitor teal, technician safety orange.
    static let uniforms = [RGBA(hex: 0x2F8F83), RGBA(hex: 0xE07B28)]
    static let bottoms = [RGBA(hex: 0x2A2F38), RGBA(hex: 0x3E4F6B), RGBA(hex: 0x5C5248), RGBA(hex: 0x1E1F21)]

    /// Figure drawing for a look, pose and walk frame (0..<walkFrames).
    public static func figure(_ look: PersonLook, pose: PersonPose, frame: Int) -> Drawing {
        var d = Drawing()
        let skin = skins[look.skin], hair = hairs[look.hair]
        let top = look.uniform > 0 ? uniforms[look.uniform - 1] : look.business ? businessTops[look.top] : casualTops[look.top]
        let bottom = look.uniform > 0 ? uniforms[look.uniform - 1].shaded(0.8) : bottoms[look.bottom]
        let shoe = RGBA(hex: 0x1C1C1C)
        let cx = width / 2
        // Leg swing per frame (radians-ish offsets in meters at the feet).
        let swings: [Double] = pose == .walking ? [0.16, 0.05, -0.16, -0.05] : [0.03, 0.03, 0.03, 0.03]
        let swing = swings[((frame % walkFrames) + walkFrames) % walkFrames]
        let hip = Vec2(cx, 0.88)
        // Back leg (darker), then front leg.
        for (sign, shade) in [(-1.0, 0.8), (1.0, 1.0)] {
            let foot = Vec2(cx + sign * swing, 0.07)
            d.line([hip, Vec2((hip.x + foot.x) / 2 + 0.02, 0.45), foot], bottom.shaded(shade), width: 0.13)
            d.add(DrawItem(shape: .ellipse(Rect(x: foot.x - 0.05, y: 0, width: 0.17, height: 0.07)), fill: .solid(shoe.shaded(shade))))
        }
        // Torso.
        d.add(DrawItem(shape: .polygon([Vec2(cx - 0.15, 0.86), Vec2(cx + 0.15, 0.86), Vec2(cx + 0.17, 1.42), Vec2(cx - 0.16, 1.42)]),
                       fill: .linear(start: Vec2(cx - 0.16, 1.4), end: Vec2(cx + 0.17, 0.9),
                                     stops: [GradientStop(0, top.shaded(1.08)), GradientStop(1, top.shaded(0.85))])))
        if look.business {
            // Shirt collar and tie hint.
            d.polygon([Vec2(cx + 0.02, 1.42), Vec2(cx + 0.12, 1.42), Vec2(cx + 0.07, 1.28)], RGBA(hex: 0xF4F4F0))
            d.line([Vec2(cx + 0.07, 1.38), Vec2(cx + 0.075, 1.1)], RGBA(hex: 0x8C2F2A), width: 0.035)
        }
        // Arm (swings opposite to the front leg).
        let armSwing = -swing * 0.8
        d.line([Vec2(cx, 1.38), Vec2(cx + armSwing * 0.5, 1.1), Vec2(cx + armSwing, 0.9)], top.shaded(0.8), width: 0.09)
        d.ellipse(Rect(center: Vec2(cx + armSwing, 0.88), size: Vec2(0.08, 0.08)), skin)
        // Neck, head, hair.
        d.fill(Rect(x: cx - 0.04, y: 1.42, width: 0.08, height: 0.07), skin.shaded(0.9))
        d.ellipse(Rect(x: cx - 0.11, y: 1.47, width: 0.23, height: 0.27), skin)
        d.add(DrawItem(shape: .polygon([Vec2(cx - 0.12, 1.6), Vec2(cx - 0.1, 1.72), Vec2(cx + 0.02, 1.76), Vec2(cx + 0.12, 1.7),
                                        Vec2(cx + 0.1, 1.65), Vec2(cx - 0.02, 1.66), Vec2(cx - 0.06, 1.56)]), fill: .solid(hair)))
        // Eye hint (faces right).
        d.ellipse(Rect(center: Vec2(cx + 0.07, 1.62), size: Vec2(0.025, 0.025)), RGBA(hex: 0x1E1F21))
        return d
    }
}

extension PersonSprite {
    /// The figure placed in world coordinates (for vector previews; the app uses textures).
    public var worldDrawing: Drawing {
        let figure = PersonArt.figure(look, pose: pose, frame: frame)
        let origin = position - Vec2(PersonArt.width / 2, 0)
        return figure.mapped { p in
            Vec2(origin.x + (facing >= 0 ? p.x : PersonArt.width - p.x), origin.y + p.y)
        }
    }
}

/// What the renderer needs to draw one person this frame.
public struct PersonSprite: Hashable, Sendable {
    public var id: PersonID
    /// Feet position in world meters.
    public var position: Vec2
    /// +1 facing right, −1 facing left.
    public var facing: Double
    public var pose: PersonPose
    public var frame: Int
    public var look: PersonLook
}

/// Selects and positions visible people at a (fractional) time. Pure: the simulation state
/// is only read. People outside, off-screen, or too small to see are skipped (render LOD);
/// they keep being simulated.
public enum PeopleView {
    /// Below this zoom (points per meter) people are not drawn.
    public static let minZoom = 3.5
    /// Walk-cycle stride: one frame per this many meters walked.
    static let metersPerFrame = 0.32

    /// Where the i-th person in an elevator queue stands, relative to the landing (doors'
    /// centre): first two at the doors, then alternating outward.
    static func queueOffset(_ i: Int) -> Double {
        let rank = Double(i / 2)
        let side: Double = i % 2 == 0 ? -1 : 1
        return side * (0.35 + 0.55 * rank)
    }

    /// Standing spots inside a car, around the shaft centre (two rows staggered).
    static func carSlot(_ i: Int) -> Double {
        let offsets = [-0.2, 0.25, -0.65, 0.7, 0.0, -0.45, 0.45, -0.85, 0.85]
        return offsets[i % offsets.count]
    }

    /// Position of each waiting person in their queue (order: since, id).
    static func queuePositions(_ world: GameWorld) -> [PersonID: Int] {
        var queues: [String: [(Tick, PersonID)]] = [:]
        for p in world.people {
            guard case let .waiting(ride, _, since) = p.place else { continue }
            queues["\(ride.shaft.raw)/\(ride.fromFloor)", default: []].append((since, p.id))
        }
        var index: [PersonID: Int] = [:]
        for list in queues.values {
            for (i, entry) in list.sorted(by: { ($0.0, $0.1) < ($1.0, $1.1) }).enumerated() { index[entry.1] = i }
        }
        return index
    }

    public static func visible(world: GameWorld, propertyID: PropertyID, time: Double, visible: Rect, zoom: Double) -> [PersonSprite] {
        guard zoom >= minZoom else { return [] }
        let grid = world.grid
        let area = visible.insetBy(dx: -2, dy: -2)
        let buildings = Set(world.buildings(on: propertyID).map(\.id))
        var sprites: [PersonSprite] = []
        let queues = queuePositions(world)
        for p in world.people where buildings.contains(p.buildingID) {
            switch p.place {
            case .outside:
                continue
            case let .room(roomID, x):
                guard let room = world.rooms[roomID] else { continue }
                let pos = Vec2(x, grid.y(ofFloor: room.floors.lowest) + 0.08)
                guard area.contains(pos) else { continue }
                sprites.append(PersonSprite(id: p.id, position: pos, facing: p.traits & 1 == 0 ? 1 : -1,
                                            pose: .standing, frame: 0, look: PersonLook(traits: p.traits, role: p.role)))
            case let .travelling(legs, _):
                guard let s = PersonMotion.sample(legs, at: time, grid: grid) else { continue }
                let pos = s.position + Vec2(0, 0.08)
                guard area.contains(pos) else { continue }
                let travelled = abs(pos.x) + abs(pos.y) * 1.5
                let frame = Int((travelled / metersPerFrame).rounded(.down)) % PersonArt.walkFrames
                sprites.append(PersonSprite(id: p.id, position: pos, facing: s.direction, pose: .walking,
                                            frame: frame, look: PersonLook(traits: p.traits, role: p.role)))
            case let .waiting(ride, _, _):
                // Queue in front of the landing doors, spreading out to both sides.
                let pos = Vec2(ride.x + queueOffset(queues[p.id] ?? 0), grid.y(ofFloor: ride.fromFloor) + 0.08)
                guard area.contains(pos) else { continue }
                sprites.append(PersonSprite(id: p.id, position: pos, facing: 1, pose: .standing, frame: 0,
                                            look: PersonLook(traits: p.traits, role: p.role)))
            case let .riding(ride, _):
                guard let car = world.elevators[ride.shaft], let slot = car.passengers.firstIndex(of: p.id) else { continue }
                let pos = Vec2(ride.x + carSlot(slot), ElevatorMotion.y(of: car, at: time, grid: grid) + 0.08)
                guard area.contains(pos) else { continue }
                sprites.append(PersonSprite(id: p.id, position: pos, facing: slot % 2 == 0 ? 1 : -1, pose: .standing,
                                            frame: 0, look: PersonLook(traits: p.traits, role: p.role)))
            }
        }
        return sprites
    }
}
