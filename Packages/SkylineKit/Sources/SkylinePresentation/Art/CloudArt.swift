import Foundation
import SkylineCore

/// One cloud in the sky, world meters.
public struct CloudPuff: Equatable, Sendable {
    public var center: Vec2
    public var size: Vec2
    public var opacity: Double
}

/// Clouds drifting behind the skyline (Phase 20): a deterministic field per city seed,
/// moved by game time (so pausing stops them and speed-up hurries them), as many and as
/// dense as the weather's cloud cover asks. Pure presentation.
public enum CloudView {
    /// Mean drift, meters per game second.
    public static let wind = 1.2
    /// Width of the repeating cloud field around the site.
    static let span = 3000.0

    public static func clouds(seed: UInt64, time: Double, cover: Double, centerX: Double, visible: Rect? = nil) -> [CloudPuff] {
        let cover = min(max(cover, 0), 1)
        let count = Int((5 + 25 * cover).rounded())             // a few fair-weather clouds even on clear days
        var out: [CloudPuff] = []
        for i in 0..<count {
            var rng = SeededRandom(seed: seed, stream: 0xC10D &+ UInt64(i))
            let base = rng.double(in: 0..<span)
            let altitude = rng.double(in: 180..<820)
            let width = rng.double(in: 140..<420) * (0.7 + 0.6 * cover)
            let height = width * rng.double(in: 0.22..<0.38)
            let speed = wind * rng.double(in: 0.6..<1.4)
            let shade = rng.double(in: 0.7..<1)
            var x = (base + time * speed).truncatingRemainder(dividingBy: span)
            if x < 0 { x += span }
            let puff = CloudPuff(center: Vec2(centerX - span / 2 + x, altitude), size: Vec2(width, height),
                                 opacity: (0.45 + 0.5 * cover) * shade)
            if let visible {
                let r = Rect(minX: puff.center.x - width / 2, minY: altitude - height / 2, maxX: puff.center.x + width / 2, maxY: altitude + height / 2)
                guard r.intersects(visible) else { continue }
            }
            out.append(puff)
        }
        return out
    }
}
