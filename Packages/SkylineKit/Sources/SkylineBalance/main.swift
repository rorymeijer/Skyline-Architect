// skyline-balance — plays every scenario with the balance bot (F1) and prints a Markdown
// report. `swift run -c release skyline-balance [--scenario id] [--out file.md]`.
import Foundation
import SkylineBot
import SkylineContent
import SkylineCore

let args = Array(CommandLine.arguments.dropFirst())
func option(_ name: String) -> String? {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    return args[i + 1]
}

do {
    let library = try ContentLibrary.loadBase()
    let ids = option("--scenario").map { [$0] } ?? library.orderedScenarios.map(\.id)
    var lines = ["| Scenario | Result | Day | Stars | Points | Floors | Population | Units | Lowest cash | Objectives (last measured) |",
                 "|----------|--------|----:|------:|-------:|-------:|-----------:|------:|------------:|-------------|"]
    var logs: [String] = []
    for id in ids {
        let start = Date()
        var bot = ScenarioBot(library: library)
        let r = try bot.play(id)
        let outcome = r.result.map { $0.won ? "won" : "lost (\($0.reason.lowercased()))" } ?? "undecided"
        let objectives = r.objectives.map { "\($0.label): \($0.value) \($0.met ? "✓" : "✗")" }.joined(separator: "; ")
        lines.append("| \(r.name) | \(outcome) | \(r.days) | \(r.result?.stars ?? 0) | \(r.result?.score ?? 0) | \(r.floors) | \(r.population) | \(r.units) | \(r.minCash) | \(objectives) |")
        logs.append("**\(r.name)** (\(String(format: "%.0f", Date().timeIntervalSince(start))) s): \(r.units) of \(r.unitsBuilt) units let; \(r.market). "
                    + (r.log.isEmpty ? "—" : r.log.prefix(8).joined(separator: " · ")))
        FileHandle.standardError.write(Data("[balance] \(id): \(outcome) on day \(r.days)\n".utf8))
    }
    let report = (lines + [""] + logs.map { "- " + $0 }).joined(separator: "\n") + "\n"
    if let out = option("--out") { try report.write(toFile: out, atomically: true, encoding: .utf8) }
    print(report)
} catch {
    FileHandle.standardError.write(Data("skyline-balance: \(error)\n".utf8))
    exit(1)
}
