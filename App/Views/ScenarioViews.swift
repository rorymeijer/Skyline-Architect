import SwiftUI
import SkylineContent
import SkylineCore
import SkylinePersistence

/// Scenario list and briefing, opened from the main menu (Phase 16).
struct ScenarioBrowserView: View {
    let model: AppModel

    var body: some View {
        let briefs = model.scenarioBriefs
        let selected = briefs.first { $0.id == model.selectedScenarioID } ?? briefs.first
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            // Where the full card does not fit (an iPhone, 0.29.2): the list without the
            // summaries, then smaller.
            ViewThatFits(in: .vertical) {
                card(briefs, selected: selected, compact: false)
                card(briefs, selected: selected, compact: true)
                card(briefs, selected: selected, compact: true).scaled(0.9)
                card(briefs, selected: selected, compact: true).scaled(0.8)
                card(briefs, selected: selected, compact: true).scaled(0.75)
            }
        }
        .environment(\.colorScheme, .dark)
    }

    private func card(_ briefs: [ScenarioBrief], selected: ScenarioBrief?, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            Text("Scenarios").font(.ui(.title2).weight(.bold))
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: compact ? 4 : 6) {
                    ForEach(briefs) { b in
                        Button { model.selectedScenarioID = b.id } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(b.name).font(.ui(.headline))
                                    Spacer()
                                    if let r = model.scenarioRecords.record(for: b.id) { Stars(count: r.bestStars, size: 10) }
                                    DifficultyTag(text: b.difficulty)
                                }
                                if !compact {
                                    Text(b.summary).font(.ui(.caption)).foregroundStyle(.secondary).lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(compact ? 7 : 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(b.id == selected?.id ? 0.22 : 0.08)))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .scaledFrame(width: 280)
                if let s = selected {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(s.name).font(.ui(.title3).weight(.semibold))
                        Text(s.setting).font(.ui(.caption).monospacedDigit()).foregroundStyle(.secondary)
                        Text(s.briefing).font(.ui(.callout)).fixedSize(horizontal: false, vertical: true)
                        Divider()
                        Text("Objectives").font(.ui(.caption).weight(.semibold))
                        ForEach(s.objectives, id: \.self) { o in
                            Label(o, systemImage: "flag").font(.ui(.callout))
                        }
                        if s.holdDays > 1 {
                            Text("All at once, at \(s.holdDays) daily closings in a row.").font(.ui(.caption)).foregroundStyle(.secondary)
                        } else {
                            Text("All at once, at a daily closing.").font(.ui(.caption)).foregroundStyle(.secondary)
                        }
                        if !s.restrictions.isEmpty {
                            Text("Rules").font(.ui(.caption).weight(.semibold))
                            ForEach(s.restrictions, id: \.self) { r in Label(r, systemImage: "nosign").font(.ui(.callout)) }
                        }
                        if s.events > 0 {
                            Text("\(s.events) scripted event\(s.events == 1 ? "" : "s") along the way.").font(.ui(.caption)).foregroundStyle(.secondary)
                        }
                        if let r = model.scenarioRecords.record(for: s.id) {
                            HStack(spacing: 6) {
                                Stars(count: r.bestStars, size: 12)
                                Text("Best \(r.bestScore) points · \(r.wins) of \(r.attempts) won"
                                     + (r.fastestDays.map { " · fastest \($0) days" } ?? ""))
                                    .font(.ui(.caption).monospacedDigit()).foregroundStyle(.secondary)
                            }
                        }
                        HStack {
                            MenuButton(title: "Back", subtitle: nil) { model.showScenarioBrowser = false }
                            MenuButton(title: "Start \(s.name)", subtitle: nil) { model.startScenario(s.id) }
                        }
                    }
                    .scaledFrame(width: 340, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(compact ? 18 : 28)
        .fixedSize(horizontal: false, vertical: true)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

/// Up to three stars, filled for those earned (Phase C).
struct Stars: View {
    let count: Int
    var size: CGFloat = 12

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < count ? "star.fill" : "star").font(.system(size: size))
                    .foregroundStyle(i < count ? Color.yellow : Color.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) of 3 stars")
    }
}

private struct DifficultyTag: View {
    let text: String

    var body: some View {
        Text(text).font(.ui(.caption2).weight(.semibold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.35)))
    }

    private var color: Color { text == "Easy" ? .green : text == "Medium" ? .yellow : .red }
}

/// The scenario's objectives with live progress (⌥⌘O).
struct ScenarioPanel: View {
    let model: AppModel

    var body: some View {
        if let s = model.scenario {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(s.name).font(.ui(.headline))
                    Spacer()
                    CloseButton { model.showScenarioPanel = false }
                }
                if let r = s.result {
                    Text(r.won ? "Won on day \(SimClock.day(r.tick) + 1)" : "Lost on day \(SimClock.day(r.tick) + 1) — \(r.reason.lowercased())")
                        .font(.ui(.caption).weight(.semibold)).foregroundStyle(r.won ? Color.green : Color.orange)
                } else {
                    Text("\(s.daysLeft) daily closing\(s.daysLeft == 1 ? "" : "s") left"
                         + (s.holdDays > 1 ? " · held \(s.streak)/\(s.holdDays) in a row" : ""))
                        .font(.ui(.caption).monospacedDigit()).foregroundStyle(.secondary)
                }
                ScenarioRows(rows: s.rows)
                if s.result == nil {
                    Text("Checked at every daily closing (06:00).").font(.ui(.caption2)).foregroundStyle(.secondary)
                }
                if !s.restrictions.isEmpty {
                    Text("Rules: " + s.restrictions.joined(separator: " · ")).font(.ui(.caption2)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !s.news.isEmpty {
                    Divider()
                    ForEach(s.news, id: \.self) { line in
                        Label(line, systemImage: "newspaper").font(.ui(.caption2)).lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(12)
            .scaledFrame(width: 330, alignment: .leading)
            .panelCard()
            .environment(\.colorScheme, .dark)
        }
    }
}

private struct ScenarioRows: View {
    let rows: [ScenarioSummary.Row]

    var body: some View {
        ForEach(rows, id: \.label) { r in
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: r.met ? "checkmark.circle.fill" : "circle").foregroundStyle(r.met ? Color.green : Color.secondary)
                    Text(r.label).font(.ui(.caption))
                    Spacer()
                    Text(r.current).font(.ui(.caption).monospacedDigit()).foregroundStyle(.secondary)
                }
                ProgressBar(value: r.fraction, tint: r.met ? .green : .accentColor)
            }
        }
    }
}

/// Announced once when a daily closing decides the scenario.
struct ScenarioResultView: View {
    let model: AppModel

    var body: some View {
        if let s = model.scenario, let r = s.result {
            ZStack {
                Color.black.opacity(0.5).ignoresSafeArea()
                // Compact (an iPhone, 0.29.2): stars beside the points, the buttons in a row.
                ViewThatFits(in: .vertical) {
                    card(s, r, compact: false)
                    card(s, r, compact: true)
                    card(s, r, compact: true).scaled(0.9)
                    card(s, r, compact: true).scaled(0.8)
                }
            }
            .environment(\.colorScheme, .dark)
        }
    }

    private func card(_ s: ScenarioSummary, _ r: ScenarioResult, compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 10) {
            Image(systemName: r.won ? "trophy.fill" : "hourglass.bottomhalf.filled").font(.system(size: compact ? 26 : 36))
                .foregroundStyle(r.won ? Color.yellow : Color.orange)
            Text(r.won ? "Scenario complete" : "Scenario failed").font(.ui(compact ? .title : .largeTitle).weight(.bold))
            Text("\(s.name) · \(r.reason) · day \(SimClock.day(r.tick) + 1)").font(.ui(.callout)).foregroundStyle(.secondary)
            if compact {
                HStack(spacing: 12) {
                    if r.won { Stars(count: r.stars ?? 1, size: 20) }
                    score(r)
                }
            } else {
                if r.won { Stars(count: r.stars ?? 1, size: 26) }
                score(r)
            }
            VStack(alignment: .leading, spacing: 6) { ScenarioRows(rows: s.rows) }
                .scaledFrame(width: 320)
                .padding(.vertical, compact ? 2 : 6)
            if compact {
                HStack(spacing: 8) { buttons(width: 200) }
            } else {
                buttons(width: 280)
            }
        }
        .padding(compact ? 20 : 32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder private func score(_ r: ScenarioResult) -> some View {
        if let score = r.score {
            Text("\(score) points" + (model.scenarioNewBest ? " · new best!" : "")).font(.ui(.title3).monospacedDigit().weight(.semibold))
                .foregroundStyle(model.scenarioNewBest ? Color.yellow : Color.primary)
        }
    }

    @ViewBuilder private func buttons(width: CGFloat) -> some View {
        MenuButton(title: "Keep Playing", subtitle: "The estate stays yours as free play") { model.keepPlaying() }.scaledFrame(width: width)
        MenuButton(title: "Scenarios…", subtitle: nil) { model.openScenarioBrowser() }.scaledFrame(width: width)
        MenuButton(title: "Main Menu", subtitle: nil) { model.returnToMainMenu() }.scaledFrame(width: width)
    }
}
