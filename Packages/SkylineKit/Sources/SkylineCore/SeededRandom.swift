import Foundation

/// Deterministic pseudo-random generator (SplitMix64). Identical sequences on every
/// platform and every run for the same seed. Use this — never `SystemRandomNumberGenerator`
/// — for anything that affects simulation state or procedural content.
public struct SeededRandom: RandomNumberGenerator, Codable, Sendable, Hashable {
    public private(set) var state: UInt64

    public init(seed: UInt64) { state = seed }

    /// Derives an independent stream, e.g. per subsystem or per procedural element.
    public init(seed: UInt64, stream: UInt64) {
        var mixer = SeededRandom(seed: seed ^ (stream &* 0x9E37_79B9_7F4A_7C15))
        state = mixer.next()
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform double in [0, 1). Platform-independent (does not rely on stdlib float
    /// generation details).
    public mutating func unit() -> Double {
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }

    /// Uniform double in [lower, upper).
    public mutating func double(in range: Range<Double>) -> Double {
        range.lowerBound + unit() * (range.upperBound - range.lowerBound)
    }

    /// Uniform integer in [lower, upper).
    public mutating func int(in range: Range<Int>) -> Int {
        precondition(!range.isEmpty)
        let span = UInt64(range.upperBound - range.lowerBound)
        return range.lowerBound + Int(next() % span)
    }

    public mutating func chance(_ probability: Double) -> Bool { unit() < probability }
}

/// Stable 64-bit FNV-1a hash of a string, for deriving seeds from content ids.
/// (`String.hashValue` is randomized per process and must not be used for seeds.)
public func stableHash(_ string: String) -> UInt64 {
    var h: UInt64 = 0xcbf2_9ce4_8422_2325
    for b in string.utf8 {
        h ^= UInt64(b)
        h &*= 0x0000_0100_0000_01B3
    }
    return h
}
