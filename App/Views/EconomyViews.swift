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
                Text("Economy").font(.ui(.headline))
                Spacer()
                CloseButton { model.showEconomyPanel = false }
            }
            HStack {
                Text("Cash").foregroundStyle(.secondary)
                Spacer()
                Text(Money.format(e.cash)).font(.ui(.title3).monospacedDigit().weight(.semibold))
                    .foregroundStyle(e.cash < 0 ? Color.red : Color.primary)
            }
            if e.negativeDays > 0 {
                Text("In the red for \(e.negativeDays) of \(e.bankruptcyDays) days — bankruptcy after \(e.bankruptcyDays).")
                    .font(.ui(.caption)).foregroundStyle(.orange)
            }
            HStack(spacing: 6) {
                Text("Loans \(Money.format(e.loans))").font(.ui(.caption).monospacedDigit())
                Spacer()
                PanelButton(title: "Borrow \(Money.format(e.loanStep))", enabled: e.canBorrow) { model.borrow() }
                PanelButton(title: "Repay", enabled: e.canRepay) { model.repay() }
            }
            HStack(spacing: 6) {
                Text("Rent level \(Int((e.rentLevel * 100).rounded())) %").font(.ui(.caption).monospacedDigit())
                Spacer()
                if e.rentFixed {
                    Text("fixed by the scenario").font(.ui(.caption)).foregroundStyle(.secondary)
                } else {
                    PanelButton(title: "−", enabled: e.rentLevel > 0.61) { model.adjustRentLevel(by: -0.1) }
                    PanelButton(title: "+", enabled: e.rentLevel < 1.59) { model.adjustRentLevel(by: 0.1) }
                }
            }
            Text(String(format: "Energy price %.2f× today · tax level %.0f %%", e.energyPrice, e.taxLevel * 100))
                .font(.ui(.caption).monospacedDigit()).foregroundStyle(.secondary)
                .help("Energy prices move every morning and scale utilities and lighting; taxes follow the city's level (Phase E).")
            Divider()
            Text("Today and last 7 days").font(.ui(.caption).weight(.semibold))
            ForEach(LedgerCategory.allCases, id: \.self) { c in
                let today = e.lastDay.amount(c), week = e.week.amount(c)
                if today != 0 || week != 0 {
                    HStack {
                        Text(c.rawValue.capitalized).font(.ui(.caption))
                        Spacer()
                        Text(Money.format(today)).font(.ui(.caption).monospacedDigit()).scaledFrame(width: 90, alignment: .trailing)
                        Text(Money.format(week)).font(.ui(.caption).monospacedDigit()).foregroundStyle(.secondary)
                            .scaledFrame(width: 100, alignment: .trailing)
                    }
                }
            }
            HStack {
                Text("Net").font(.ui(.caption).weight(.semibold))
                Spacer()
                Text(Money.format(e.lastDay.income + e.lastDay.expenses)).font(.ui(.caption).monospacedDigit().weight(.semibold))
                    .scaledFrame(width: 90, alignment: .trailing)
                Text(Money.format(e.week.income + e.week.expenses)).font(.ui(.caption).monospacedDigit())
                    .scaledFrame(width: 100, alignment: .trailing)
            }
            Divider()
            ForEach(Array(e.recent.enumerated()), id: \.offset) { _, t in
                HStack(spacing: 6) {
                    Text("D\(SimClock.day(t.tick) + 1) \(SimClock.timeString(t.tick))").font(.ui(.caption2).monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(t.detail).font(.ui(.caption2)).lineLimit(1)
                    Spacer()
                    Text(Money.format(t.amount)).font(.ui(.caption2).monospacedDigit())
                        .foregroundStyle(t.amount < 0 ? Color.orange : Color.green)
                }
            }
        }
        .padding(12)
        .scaledFrame(width: 360, alignment: .leading)
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
            Text(title).font(.ui(.caption).weight(.medium))
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

    private struct Item: Identifiable {
        let title: String
        let subtitle: String?
        let action: () -> Void
        var id: String { title }
    }

    private var items: [Item] {
        var items: [Item] = []
        if model.menuOverGame {
            items.append(Item(title: "Resume", subtitle: model.propertyName) { model.resumeFromMenu() })
        } else if let latest = model.latestSave {
            items.append(Item(title: "Continue", subtitle: latest.metadata.map { "\($0.title) · \($0.savedAt.formatted(date: .abbreviated, time: .shortened))" }) {
                model.continueLatest()
            })
        }
        items += [
            Item(title: "Tutorial", subtitle: "Your first tower, step by step") { model.startTutorial() },
            Item(title: "New Game", subtitle: "Quay Street, Port Calder · rooms unlock by class") { model.startFromMenu() },
            Item(title: "New Sandbox", subtitle: "Everything unlocked from the start") { model.startFromMenu(startID: NewGameFactory.defaultStartID) },
            Item(title: "Scenarios…", subtitle: "Objectives against the clock") { model.openScenarioBrowser() },
            Item(title: "Mods…", subtitle: model.enabledMods.isEmpty ? "Content packs" : "\(model.enabledMods.count) enabled") { model.openModManager() },
            Item(title: "Load Game…", subtitle: nil) { model.openSavesPanel() },
            Item(title: "Manual", subtitle: "How everything works") { model.openManual() },
            Item(title: "Text Size: \(TextSizeSetting.name(model.textSize))", subtitle: "Panels and menus") {
                model.textSize = TextSizeSetting.next(after: model.textSize)
            },
        ]
        return items
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            // One column; where that is too tall (F5, an iPhone in landscape), two columns and
            // a smaller title.
            ViewThatFits(in: .vertical) {
                menu(columns: 1, titleSize: 34, padding: 36)
                menu(columns: 2, titleSize: 22, padding: 16)
            }
        }
        .environment(\.colorScheme, .dark)
    }

    private func menu(columns: Int, titleSize: CGFloat, padding: CGFloat) -> some View {
        let items = self.items
        let perColumn = (items.count + columns - 1) / columns
        return VStack(spacing: columns == 1 ? 14 : 8) {
            Text("SKYLINE ARCHITECT").font(.system(size: titleSize, weight: .heavy, design: .rounded)).kerning(columns == 1 ? 4 : 2)
            Text("Build upward. Keep the building moving.").font(.ui(.callout)).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 8) {
                ForEach(0..<columns, id: \.self) { c in
                    VStack(spacing: columns == 1 ? 8 : 6) {
                        ForEach(items[(c * perColumn)..<min((c + 1) * perColumn, items.count)]) { item in
                            MenuButton(title: item.title, subtitle: item.subtitle, action: item.action)
                        }
                    }
                    .scaledFrame(width: columns == 1 ? 300 : 260)
                }
            }
            .padding(.top, columns == 1 ? 8 : 2)
        }
        .padding(padding)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

/// Shown when seven daily closings in a row end in the red.
struct BankruptcyView: View {
    let model: AppModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("Bankrupt").font(.ui(.largeTitle).weight(.bold))
                Text("Cash stayed below zero for \(model.economy.bankruptcyDays) daily closings in a row. The creditors take over the building.")
                    .multilineTextAlignment(.center).scaledFrame(width: 320).foregroundStyle(.secondary)
                MenuButton(title: "New Game", subtitle: nil) { model.startFromMenu() }.scaledFrame(width: 260)
                MenuButton(title: "Load Game…", subtitle: nil) { model.openSavesPanel() }.scaledFrame(width: 260)
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
                Text(title).font(.ui(.headline))
                if let subtitle { Text(subtitle).font(.ui(.caption)).foregroundStyle(.secondary).lineLimit(1) }
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
