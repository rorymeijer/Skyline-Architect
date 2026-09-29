import SwiftUI
import SkylineContent
import SkylineCore
import SkylinePresentation
import SkylineSimulation

/// Cash, loans, rent level and where the money went (⌥⌘M). Every line traces to a
/// ledger transaction.
struct EconomyPanel: View {
    let model: AppModel

    var body: some View {
        let e = model.economy
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Economy").font(.headline)
                Spacer()
                CloseButton { model.showEconomyPanel = false }
            }
            HStack {
                Text("Cash").foregroundStyle(.secondary)
                Spacer()
                Text(Money.format(e.cash)).font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(e.cash < 0 ? Color.red : Color.primary)
            }
            if e.negativeDays > 0 {
                Text("In the red for \(e.negativeDays) of \(e.bankruptcyDays) days — bankruptcy after \(e.bankruptcyDays).")
                    .font(.caption).foregroundStyle(.orange)
            }
            HStack(spacing: 6) {
                Text("Loans \(Money.format(e.loans))").font(.caption.monospacedDigit())
                Spacer()
                PanelButton(title: "Borrow \(Money.format(e.loanStep))", enabled: e.canBorrow) { model.borrow() }
                PanelButton(title: "Repay", enabled: e.canRepay) { model.repay() }
            }
            HStack(spacing: 6) {
                Text("Rent level \(Int((e.rentLevel * 100).rounded())) %").font(.caption.monospacedDigit())
                Spacer()
                if e.rentFixed {
                    Text("fixed by the scenario").font(.caption).foregroundStyle(.secondary)
                } else {
                    PanelButton(title: "−", enabled: e.rentLevel > 0.61) { model.adjustRentLevel(by: -0.1) }
                    PanelButton(title: "+", enabled: e.rentLevel < 1.59) { model.adjustRentLevel(by: 0.1) }
                }
            }
            Text(String(format: "Energy price %.2f× today · tax level %.0f %%", e.energyPrice, e.taxLevel * 100))
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                .help("Energy prices move every morning and scale utilities and lighting; taxes follow the city's level (Phase E).")
            Divider()
            Text("Today and last 7 days").font(.caption.weight(.semibold))
            ForEach(LedgerCategory.allCases, id: \.self) { c in
                let today = e.lastDay.amount(c), week = e.week.amount(c)
                if today != 0 || week != 0 {
                    HStack {
                        Text(c.rawValue.capitalized).font(.caption)
                        Spacer()
                        Text(Money.format(today)).font(.caption.monospacedDigit()).frame(width: 90, alignment: .trailing)
                        Text(Money.format(week)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            .frame(width: 100, alignment: .trailing)
                    }
                }
            }
            HStack {
                Text("Net").font(.caption.weight(.semibold))
                Spacer()
                Text(Money.format(e.lastDay.income + e.lastDay.expenses)).font(.caption.monospacedDigit().weight(.semibold))
                    .frame(width: 90, alignment: .trailing)
                Text(Money.format(e.week.income + e.week.expenses)).font(.caption.monospacedDigit())
                    .frame(width: 100, alignment: .trailing)
            }
            Divider()
            ForEach(Array(e.recent.enumerated()), id: \.offset) { _, t in
                HStack(spacing: 6) {
                    Text("D\(SimClock.day(t.tick) + 1) \(SimClock.timeString(t.tick))").font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(t.detail).font(.caption2).lineLimit(1)
                    Spacer()
                    Text(Money.format(t.amount)).font(.caption2.monospacedDigit())
                        .foregroundStyle(t.amount < 0 ? Color.orange : Color.green)
                }
            }
        }
        .padding(12)
        .frame(width: 360, alignment: .leading)
        .panelCard()
        .environment(\.colorScheme, .dark)
    }
}

/// SwiftUI-drawn button (AppKit buttons render as placeholders in captures).
struct PanelButton: View {
    let title: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).font(.caption.weight(.medium))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(enabled ? 0.15 : 0.05)))
                .focusRing(cornerRadius: 6)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
    }
}

/// Start screen: continue the newest save, start a new game, load one.
struct MainMenuView: View {
    let model: AppModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("SKYLINE ARCHITECT").font(.system(size: 34, weight: .heavy, design: .rounded)).kerning(4)
                Text("Build upward. Keep the building moving.").font(.callout).foregroundStyle(.secondary)
                VStack(spacing: 8) {
                    if model.menuOverGame {
                        MenuButton(title: "Resume", subtitle: model.propertyName) { model.resumeFromMenu() }
                    } else if let latest = model.latestSave {
                        MenuButton(title: "Continue", subtitle: latest.metadata.map { "\($0.title) · \($0.savedAt.formatted(date: .abbreviated, time: .shortened))" }) {
                            model.continueLatest()
                        }
                    }
                    MenuButton(title: "Tutorial", subtitle: "Your first tower, step by step") { model.startTutorial() }
                    MenuButton(title: "New Game", subtitle: "Quay Street, Port Calder · rooms unlock by class") {
                        model.startFromMenu()
                    }
                    MenuButton(title: "New Sandbox", subtitle: "Everything unlocked from the start") {
                        model.startFromMenu(startID: NewGameFactory.defaultStartID)
                    }
                    MenuButton(title: "Scenarios…", subtitle: "Objectives against the clock") { model.openScenarioBrowser() }
                    MenuButton(title: "Mods…", subtitle: model.enabledMods.isEmpty ? "Content packs" : "\(model.enabledMods.count) enabled") {
                        model.openModManager()
                    }
                    MenuButton(title: "Load Game…", subtitle: nil) { model.openSavesPanel() }
                    MenuButton(title: "Manual", subtitle: "How everything works") { model.openManual() }
                    MenuButton(title: "Text Size: \(TextSizeSetting.name(model.textSize))", subtitle: "Panels and menus") {
                        model.textSize = TextSizeSetting.next(after: model.textSize)
                    }
                }
                .frame(width: 300)
                .padding(.top, 8)
            }
            .padding(36)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
        .environment(\.colorScheme, .dark)
    }
}

/// Shown when seven daily closings in a row end in the red.
struct BankruptcyView: View {
    let model: AppModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("Bankrupt").font(.largeTitle.weight(.bold))
                Text("Cash stayed below zero for \(model.economy.bankruptcyDays) daily closings in a row. The creditors take over the building.")
                    .multilineTextAlignment(.center).frame(width: 320).foregroundStyle(.secondary)
                MenuButton(title: "New Game", subtitle: nil) { model.startFromMenu() }.frame(width: 260)
                MenuButton(title: "Load Game…", subtitle: nil) { model.openSavesPanel() }.frame(width: 260)
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
        .environment(\.colorScheme, .dark)
    }
}

struct MenuButton: View {
    let title: String
    let subtitle: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title).font(.headline)
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.12)))
            .focusRing(cornerRadius: 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
