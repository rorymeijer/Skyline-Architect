import Foundation
import SkylineCore

/// Emergencies and incidents (`events.json`, Phase 14).
public struct EventRules: Codable, Hashable, Sendable {
    /// Fire: ignition, growth and spread per step, suppression, damage and consequences.
    public struct FireRules: Codable, Hashable, Sendable {
        /// Chance per room per game day (checked hourly).
        public var ignitionPerRoomPerDay: Double
        /// Rooms below this condition ignite `wornMultiplier` times as often.
        public var wornBelow: Double
        public var wornMultiplier: Double
        /// Equipment rooms (utility supply) ignite this many times as often.
        public var equipmentMultiplier: Double
        /// Sprinkler-protected rooms ignite this fraction as often.
        public var protectedIgnitionFactor: Double
        /// Game seconds between fire steps.
        public var stepSeconds: Int
        public var startIntensity: Double
        public var growthPerStep: Double
        /// Rooms burning at least this strongly can spread to neighbours.
        public var spreadAbove: Double
        public var spreadChancePerStep: Double
        /// Spread into a protected room is this fraction as likely.
        public var protectedSpreadFactor: Double
        public var sprinklerSuppressionPerStep: Double
        public var brigadeResponseMinutes: Int
        public var brigadeSuppressionPerStep: Double
        /// Condition and cleanliness lost per step at full intensity.
        public var damagePerStep: Double
        /// Units whose condition ends below this are unusable: the tenant leaves.
        public var destroyedBelow: Double
        /// Repair bill per module per floor of every room the fire reached.
        public var repairCostPerModule: Int
        public var reputationPenalty: Double

        public var problems: [String] {
            var p: [String] = []
            let fractions = [ignitionPerRoomPerDay, wornBelow, protectedIgnitionFactor, startIntensity, growthPerStep, spreadAbove,
                             spreadChancePerStep, protectedSpreadFactor, sprinklerSuppressionPerStep, brigadeSuppressionPerStep,
                             damagePerStep, destroyedBelow]
            if fractions.contains(where: { !(0...1).contains($0) }) { p.append("fire: rates and thresholds must be 0…1") }
            if wornMultiplier < 1 || equipmentMultiplier < 1 { p.append("fire: multipliers must be ≥ 1") }
            if stepSeconds < 10 || brigadeResponseMinutes < 0 || repairCostPerModule < 0 || reputationPenalty < 0 {
                p.append("fire: stepSeconds ≥ 10, response, cost and penalty ≥ 0")
            }
            return p
        }
    }

    /// A weather-driven incident: when it can happen and what it does to one room.
    public struct IncidentDefinition: Codable, Hashable, Sendable {
        public var id: String
        public var name: String
        /// Weather kinds during which it can happen.
        public var weather: [String]
        /// Only at or below this temperature (°C), if set.
        public var maxTemperature: Double?
        /// Chance per building per game day (checked hourly).
        public var chancePerDay: Double
        /// "room" (any room), or "supplies:<utility>" (equipment supplying it).
        public var target: String
        public var condition: Double
        public var cleanliness: Double
        public var cost: Int
        public var reputation: Double

        func problems(weatherKinds: Set<String>, utilities: Set<String>) -> [String] {
            var p: [String] = []
            if weather.isEmpty || !weather.allSatisfy(weatherKinds.contains) { p.append("incident '\(id)': unknown or missing weather") }
            if !(0...1).contains(chancePerDay) { p.append("incident '\(id)': chancePerDay 0…1") }
            if target != "room" && !(target.hasPrefix("supplies:") && utilities.contains(String(target.dropFirst(9)))) {
                p.append("incident '\(id)': target must be room or supplies:<utility>")
            }
            if !(-1...1).contains(condition) || !(-1...1).contains(cleanliness) || cost < 0 || reputation < 0 {
                p.append("incident '\(id)': condition/cleanliness −1…1, cost and reputation ≥ 0")
            }
            return p
        }
    }

    public var fire: FireRules
    public var incidents: [IncidentDefinition]

    public func problems(weatherKinds: Set<String>, utilities: Set<String>) -> [String] {
        var p = fire.problems
        var ids = Set<String>()
        for d in incidents {
            if !ids.insert(d.id).inserted || d.id == "fire" { p.append("incident '\(d.id)' defined twice or reserved") }
            p += d.problems(weatherKinds: weatherKinds, utilities: utilities)
        }
        return p
    }
}
