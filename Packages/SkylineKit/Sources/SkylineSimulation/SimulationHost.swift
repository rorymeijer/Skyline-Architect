import Foundation
import SkylineCore

/// Game speed. Faster speeds run more fixed ticks per real second; the tick length never
/// changes, so outcomes do not depend on the speed (SIMULATION.md).
public enum GameSpeed: Int, CaseIterable, Sendable, Codable {
    case paused = 0, normal = 1, double = 2, quadruple = 4, fastest = 10

    /// Game seconds per real second at 1×: one game hour takes 150 real seconds.
    public static let baseTicksPerSecond = 24.0

    public var ticksPerSecond: Double { Double(rawValue) * Self.baseTicksPerSecond }

    public var label: String { self == .paused ? "Paused" : "\(rawValue)×" }
}

/// Converts real (wall-clock) frame time into whole simulation ticks. Holds no game state:
/// it only decides *how many* ticks to run; `SimulationEngine` runs them.
public struct SimulationHost: Sendable {
    public var speed: GameSpeed = .normal
    /// Fraction of the next tick already elapsed in real time (for rendering interpolation).
    public private(set) var fraction = 0.0
    /// At most this many ticks per frame (a hitch must not cause a spiral of death).
    public var maxTicksPerFrame: Tick = 480

    public init(speed: GameSpeed = .normal) { self.speed = speed }

    public mutating func ticksToRun(realDelta: Double) -> Tick {
        guard speed != .paused, realDelta > 0 else { return 0 }
        let total = fraction + min(realDelta, 0.25) * speed.ticksPerSecond
        let whole = min(Tick(total.rounded(.down)), maxTicksPerFrame)
        fraction = min(total - Double(whole), 0.999)
        return whole
    }
}
