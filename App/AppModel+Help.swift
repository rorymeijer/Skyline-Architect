import Foundation
import SkylineContent
import SkylineCore
import SkylinePresentation

/// The tutorial scenario's steps with where the player stands (F3, 4 Hz).
struct TutorialSummary: Equatable {
    var steps: [TutorialStep]
    var progress: TutorialProgress

    var current: TutorialStep? { progress.current.map { steps[$0] } }
}

/// Which first-time hints this device has shown, and whether hints are on (F3). Kept in
/// the user defaults like the mod settings; screenshot captures keep it in memory only.
struct HintMemory {
    private static let seenKey = "SkylineArchitect.seenHints"
    private static let enabledKey = "SkylineArchitect.showHints"
    let persists: Bool
    private(set) var seen: Set<String>
    private(set) var enabled: Bool

    init(persists: Bool) {
        self.persists = persists
        let defaults = UserDefaults.standard
        seen = persists ? Set(defaults.stringArray(forKey: Self.seenKey) ?? []) : []
        enabled = persists ? (defaults.object(forKey: Self.enabledKey) as? Bool ?? true) : true
    }

    mutating func markSeen(_ id: String) {
        seen.insert(id)
        if persists { UserDefaults.standard.set(seen.sorted(), forKey: Self.seenKey) }
    }

    mutating func setEnabled(_ on: Bool) {
        enabled = on
        if persists { UserDefaults.standard.set(on, forKey: Self.enabledKey) }
    }

    mutating func reset() {
        seen = []
        if persists { UserDefaults.standard.removeObject(forKey: Self.seenKey) }
    }
}

extension AppModel {
    // MARK: Manual (F3)

    func loadManual() {
        do {
            manual = try ManualContent.load()
        } catch {
            manual = nil
            alert = AppAlert(title: "The manual could not be loaded", message: "\(error)")
        }
    }

    /// Opens the manual, at a chapter if given (else where it was left).
    func openManual(chapter: String? = nil) {
        if manual == nil { loadManual() }
        if let chapter { manualChapterID = chapter }
        if manualChapterID == nil { manualChapterID = manual?.document.chapters.first?.id }
        manualQuery = ""
        showManual = true
    }

    // MARK: Tutorial (F3)

    func refreshTutorial() {
        guard let world, let library else { tutorial = nil; return }
        let steps = library.tutorialSteps(for: world)
        tutorial = steps.isEmpty ? nil : TutorialSummary(steps: steps, progress: TutorialProgress(steps: steps, world: world))
    }

    // MARK: First-time hints (F3)

    /// Shows a hint the first time its moment comes (once per device), unless hints are off,
    /// another hint is showing, or a full-screen view is up.
    func hint(_ id: String) {
        guard hintMemory.enabled, !hintMemory.seen.contains(id), activeHint == nil, !showMainMenu, !showManual,
              !showScenarioBrowser, !showScenarioResult, !showLoadSheet, !showModManager,
              let hint = manual?.hint(id) else { return }
        hintMemory.markSeen(id)
        activeHint = hint
    }

    func dismissHint() { activeHint = nil }

    var hintsEnabled: Bool { hintMemory.enabled }

    func setHintsEnabled(_ on: Bool) {
        hintMemory.setEnabled(on)
        if !on { activeHint = nil }
    }

    /// Every hint shows again (Help ▸ Show All Tips Again).
    func resetHints() { hintMemory.reset() }

    /// Hints about what the world shows (4 Hz): first tenant, declines, the first night and
    /// closing, money, fire, breakdowns and promotions.
    func checkWorldHints() {
        guard let world, hintMemory.enabled, activeHint == nil else { return }
        let second = SimClock.secondOfDay(world.clock.tick)
        if !world.tenants.isEmpty { hint("first-tenant") }
        if world.market.declines(.poorServices) > 0 { hint("poor-services") }
        if world.market.declines(.poorAccess) > 0 { hint("poor-access") }
        if world.market.declines(.tooExpensive) > 0 { hint("too-expensive") }
        if SimClock.day(world.clock.tick) >= 1 { hint("first-closing") }
        if second >= 19 * 3600 || second < 5 * 3600 { hint("first-night") }
        if economy.cash < 0 { hint("cash-negative") }
        if !world.incidents.fires.isEmpty { hint("first-fire") }
        if (world.facilities.breakdowns ?? 0) > 0 { hint("first-breakdown") }
        if promotionNotice != nil { hint("promotion") }
    }

    /// Hints for the construction tools, when one is picked.
    func toolHint(_ tool: ConstructionTool?) {
        switch tool {
        case .floor: hint("floor-tool")
        case .demolish: hint("demolish-tool")
        case let .room(id):
            hint(catalog?.spec(id)?.kind == .shaft ? "shaft-tool" : "room-tool")
        case nil: break
        }
    }
}
