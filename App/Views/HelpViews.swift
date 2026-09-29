import SwiftUI
import SkylineContent

/// The manual (F3): chapters on the left with a search field, the chapter on the right.
/// Long chapters are split into pages (◀ ▶) instead of scrolling, like the saves list: all
/// plain SwiftUI, so captures render it exactly as the window does. Links to other chapters
/// (`transport.md`) open them in place.
struct ManualView: View {
    let model: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicType

    var body: some View {
        let document = model.manual?.document ?? ManualDocument(chapters: [])
        let chapter = model.manualChapterID.flatMap { document.chapter($0) } ?? document.chapters.first
        let scale = UIText.current(dynamicType)
        let pages = chapter.map { ManualPages.split($0, linesPerPage: Int((Double(ManualPages.linesPerPage) / scale).rounded(.down))) } ?? []
        let page = min(model.manualPage, max(pages.count - 1, 0))
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
                .onTapGesture { model.showManual = false }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Manual", systemImage: "book").font(.ui(.title2).weight(.bold))
                    Spacer()
                    CloseButton { model.showManual = false }
                }
                HStack(alignment: .top, spacing: 16) {
                    sidebar(document, current: chapter?.id)
                        .scaledFrame(width: 220)
                    Divider()
                    VStack(alignment: .leading, spacing: 10) {
                        if let chapter, !pages.isEmpty {
                            ManualPageView(title: page == 0 ? chapter.title : nil, blocks: pages[page])
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .clipped()
                            pager(page: page, count: pages.count, chapter: chapter, document: document)
                        } else {
                            Text("The manual is missing from this build.").foregroundStyle(.secondary)
                        }
                    }
                    .environment(\.openURL, OpenURLAction { url in
                        guard url.pathExtension == "md" else { return .systemAction }
                        model.showChapter(url.deletingPathExtension().lastPathComponent)
                        return .handled
                    })
                }
            }
            .padding(20)
            .frame(maxWidth: 880 * scale, maxHeight: 600 * scale)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .padding(24)
        }
        .environment(\.colorScheme, .dark)
    }

    private func sidebar(_ document: ManualDocument, current: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ManualSearchField(text: Binding(get: { model.manualQuery }, set: { model.manualQuery = $0 }))
            if model.manualQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                ForEach(document.chapters) { c in
                    row(title: c.title, detail: nil, selected: c.id == current) { model.showChapter(c.id) }
                }
            } else {
                let hits = document.search(model.manualQuery)
                if hits.isEmpty {
                    Text("No chapter mentions that.").font(.ui(.caption)).foregroundStyle(.secondary).padding(6)
                }
                ForEach(hits.prefix(7), id: \.chapter.id) { hit in
                    row(title: hit.chapter.title, detail: hit.snippet, selected: hit.chapter.id == current) { model.showChapter(hit.chapter.id) }
                }
                if hits.count > 7 {
                    Text("\(hits.count - 7) more — add a word").font(.ui(.caption)).foregroundStyle(.secondary).padding(.horizontal, 8)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func row(title: String, detail: String?, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.ui(.callout).weight(selected ? .semibold : .regular))
                if let detail {
                    Text(ManualMarkdown.strip(detail)).font(.ui(.caption2)).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(selected ? 0.2 : 0)))
            .focusRing(cornerRadius: 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// Previous/next page, or the neighbouring chapter at either end.
    private func pager(page: Int, count: Int, chapter: ManualChapter, document: ManualDocument) -> some View {
        let index = document.chapters.firstIndex { $0.id == chapter.id } ?? 0
        let previous = index > 0 ? document.chapters[index - 1] : nil
        let next = index + 1 < document.chapters.count ? document.chapters[index + 1] : nil
        return HStack {
            if page > 0 {
                PagerButton(title: "◀ Previous page") { model.manualPage = page - 1 }
            } else if let previous {
                PagerButton(title: "◀ \(previous.title)") { model.showChapter(previous.id) }
            }
            Spacer()
            if count > 1 {
                Text("Page \(page + 1) of \(count)").font(.ui(.caption).monospacedDigit()).foregroundStyle(.secondary)
            }
            Spacer()
            if page + 1 < count {
                PagerButton(title: "Next page ▶") { model.manualPage = page + 1 }
            } else if let next {
                PagerButton(title: "\(next.title) ▶") { model.showChapter(next.id) }
            }
        }
    }
}

private struct PagerButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).font(.ui(.callout).weight(.medium))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.12)))
                .focusRing(cornerRadius: 7)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Splits a chapter into pages that fit the manual's reading area, by an estimate of each
/// block's height in lines (about 100 characters of callout text per line, measured in
/// the captures; tables in caption type).
enum ManualPages {
    static let linesPerPage = 26

    static func split(_ chapter: ManualChapter, linesPerPage: Int = linesPerPage) -> [[ManualBlock]] {
        var pages: [[ManualBlock]] = [[]]
        var used = 3                                              // the chapter title
        for block in chapter.blocks {
            let lines = height(block)
            if used + lines > linesPerPage, !pages[pages.count - 1].isEmpty {
                // A heading never ends a page: it moves over with what follows it.
                var carried: [ManualBlock] = []
                if case .heading? = pages[pages.count - 1].last { carried.append(pages[pages.count - 1].removeLast()) }
                pages.append(carried)
                used = carried.reduce(0) { $0 + height($1) }
            }
            pages[pages.count - 1].append(block)
            used += lines
        }
        return pages.filter { !$0.isEmpty }
    }

    static func height(_ block: ManualBlock) -> Int {
        func lines(_ text: String, per: Int = 100) -> Int { max(1, (ManualMarkdown.strip(text).count + per - 1) / per) }
        switch block {
        case .heading: return 2
        case let .paragraph(t): return lines(t) + 1
        case let .note(t): return lines(t, per: 90) + 2
        case let .bullets(items), let .numbered(items): return items.reduce(1) { $0 + lines($1, per: 95) }
        case let .table(header, rows):
            let columns = max(header.count, 1)
            return rows.reduce(3) { total, row in total + (row.map { lines($0, per: 110 / columns) }.max() ?? 1) }
        }
    }
}

/// One page of a chapter, rendered natively (inline Markdown via `AttributedString`).
struct ManualPageView: View {
    let title: String?
    let blocks: [ManualBlock]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            if let title {
                Text(title).font(.ui(.title).weight(.bold)).accessibilityAddTraits(.isHeader)
            }
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: ManualBlock) -> some View {
        switch block {
        case let .heading(level, text):
            Text(Self.inline(text)).font(level <= 2 ? .title3.weight(.semibold) : .headline)
                .padding(.top, level <= 2 ? 4 : 2)
                .accessibilityAddTraits(.isHeader)
        case let .paragraph(text):
            Text(Self.inline(text)).font(.ui(.callout)).fixedSize(horizontal: false, vertical: true)
        case let .bullets(items):
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("•")
                        Text(Self.inline(item)).fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.ui(.callout))
                }
            }
        case let .numbered(items):
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(i + 1).").monospacedDigit()
                        Text(Self.inline(item)).fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.ui(.callout))
                }
            }
        case let .note(text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "lightbulb").foregroundStyle(.yellow)
                Text(Self.inline(text)).font(.ui(.callout)).fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.yellow.opacity(0.12)))
        case let .table(header, rows):
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 3) {
                GridRow { ForEach(Array(header.enumerated()), id: \.offset) { _, h in Text(Self.inline(h)).font(.ui(.caption).weight(.semibold)) } }
                Divider()
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            Text(Self.inline(cell)).font(.ui(.caption)).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    static func inline(_ markdown: String) -> AttributedString {
        (try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(markdown)
    }
}

/// The manual's search box, drawn in SwiftUI so captures show it like the window does. On a
/// Mac it takes typed keys while focused (click it); on an iPad a nearly transparent text
/// field on top brings up the on-screen keyboard.
struct ManualSearchField: View {
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        #if os(macOS)
        drawn
            .focusable()
            .focused($focused)
            .focusEffectDisabled()
            .onTapGesture { focused = true }
            .onKeyPress(phases: .down) { press in
                if press.key == .delete {
                    if !text.isEmpty { text.removeLast() }
                    return .handled
                }
                let typed = press.characters
                guard !typed.isEmpty, press.modifiers.isDisjoint(with: [.command, .control]),
                      typed.allSatisfy({ $0.isLetter || $0.isNumber || $0 == " " || $0 == "-" || $0 == "'" }) else { return .ignored }
                text += typed
                return .handled
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Search the manual")
            .accessibilityValue(text)
        #else
        drawn
            .overlay {
                TextField("", text: $text)
                    .focused($focused)
                    .opacity(0.02)                                  // UIKit field: invisible, still typable
                    .accessibilityLabel("Search the manual")
            }
        #endif
    }

    private var drawn: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            Text(text.isEmpty ? (focused ? "|" : "Search") : text + (focused ? "|" : ""))
                .foregroundStyle(text.isEmpty && !focused ? .secondary : .primary)
                .lineLimit(1)
            Spacer(minLength: 0)
            if !text.isEmpty {
                Button { text = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("Clear search")
            }
        }
        .font(.ui(.callout))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(focused ? 0.16 : 0.1)))
        .contentShape(Rectangle())
    }
}

/// The tutorial scenario's guide (F3): the step to do now, with the list of steps.
struct TutorialPanel: View {
    let model: AppModel
    let tutorial: TutorialSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Tutorial", systemImage: "graduationcap").font(.ui(.headline))
                Spacer()
                Text("\(tutorial.progress.completed) of \(tutorial.steps.count)")
                    .font(.ui(.caption).monospacedDigit()).foregroundStyle(.secondary)
                CloseButton { model.showTutorialPanel = false }
            }
            ProgressBar(value: Double(tutorial.progress.completed) / Double(max(tutorial.steps.count, 1)), tint: .green)
                .accessibilityLabel("Tutorial progress")
                .accessibilityValue("\(tutorial.progress.completed) of \(tutorial.steps.count) steps")
            if let step = tutorial.current {
                Text(step.title).font(.ui(.callout).weight(.semibold))
                Text(ManualPageView.inline(step.text)).font(.ui(.callout)).fixedSize(horizontal: false, vertical: true)
                if let chapter = step.chapter {
                    LinkButton(title: "Read more in the manual") { model.openManual(chapter: chapter) }
                }
            } else {
                Text("Every step done. Keep the units let through a closing to finish.")
                    .font(.ui(.callout)).fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(tutorial.steps.enumerated()), id: \.element.id) { i, step in
                    let done = tutorial.progress.done[i]
                    let now = i == tutorial.progress.current
                    Label(step.title, systemImage: done ? "checkmark.circle.fill" : (now ? "arrow.right.circle" : "circle"))
                        .font(.ui(.caption).weight(now ? .semibold : .regular))
                        .foregroundStyle(done ? Color.green : (now ? Color.primary : Color.secondary))
                        .accessibilityValue(done ? "Done" : (now ? "Current step" : "To do"))
                }
            }
        }
        .padding(12)
        .scaledFrame(width: 290, alignment: .leading)
        .panelCard()
        .environment(\.colorScheme, .dark)
    }
}

/// A first-time hint (F3): shown once per device, below the time controls.
struct HintBubble: View {
    let model: AppModel
    let hint: ManualHint

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Label(hint.title, systemImage: "lightbulb").font(.ui(.callout).weight(.semibold))
                Spacer()
                CloseButton { model.dismissHint() }
            }
            Text(ManualPageView.inline(hint.text)).font(.ui(.callout)).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                if let chapter = hint.chapter {
                    LinkButton(title: "Read more") {
                        model.dismissHint()
                        model.openManual(chapter: chapter)
                    }
                }
                Spacer()
                LinkButton(title: "Turn off tips", muted: true) { model.setHintsEnabled(false) }
                PagerButton(title: "Got it") { model.dismissHint() }
            }
            .font(.ui(.caption))
        }
        .padding(12)
        .scaledFrame(width: 330, alignment: .leading)
        .panelCard()
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tip: \(hint.title)")
    }
}

/// A text button in the accent colour (plain SwiftUI, so captures render it).
private struct LinkButton: View {
    let title: String
    var muted = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).font(.ui(.caption).weight(.medium)).foregroundStyle(muted ? Color.secondary : Color.accentColor)
                .padding(.horizontal, 2)
                .focusRing(cornerRadius: 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
