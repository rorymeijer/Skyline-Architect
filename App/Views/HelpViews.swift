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
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
                .onTapGesture { model.showManual = false }
            GeometryReader { geo in
                card(height: geo.size.height)
            }
            .padding(20)
            .frame(maxWidth: 880 * UIText.current(dynamicType), maxHeight: 600 * UIText.current(dynamicType))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .padding(16)
        }
        .environment(\.colorScheme, .dark)
    }

    /// The card's content for its height: the chapter list beside the page, or — where the
    /// list does not fit (F5, an iPhone in landscape) — a Contents button that shows the list
    /// in place of the page. Pages hold as many lines as the height allows.
    private func card(height: CGFloat) -> some View {
        let document = model.manual?.document ?? ManualDocument(chapters: [])
        let chapter = model.manualChapterID.flatMap { document.chapter($0) } ?? document.chapters.first
        let scale = UIText.current(dynamicType)
        #if os(macOS)
        let lineHeight = 17.5 * scale
        #else
        let lineHeight = 20 * scale
        #endif
        let compact = height < 440 * scale
        // Without the chapter list beside it, a compact page's lines hold about a third more text.
        let fitted = ((height - 85) / lineHeight).rounded(.down) * (compact ? 1.3 : 1)
        let lines = max(Int(fitted), 6)
        let pages = chapter.map { ManualPages.split($0, linesPerPage: lines) } ?? []
        let page = min(model.manualPage, max(pages.count - 1, 0))
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Manual", systemImage: "book").font(.ui(compact ? .headline : .title2).weight(.bold))
                if compact {
                    PagerButton(title: model.manualShowContents ? "Back to the page" : "Contents") { model.manualShowContents.toggle() }
                }
                Spacer()
                CloseButton { model.showManual = false }
            }
            HStack(alignment: .top, spacing: 16) {
                if !compact {
                    sidebar(document, current: chapter?.id)
                        .scaledFrame(width: 220)
                    Divider()
                }
                VStack(alignment: .leading, spacing: 10) {
                    if compact && model.manualShowContents {
                        contents(document, current: chapter?.id)
                    } else if let chapter, !pages.isEmpty {
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
    }

    /// The compact chapter list: search, then the chapters (or the hits) in two columns.
    private func contents(_ document: ManualDocument, current: String?) -> some View {
        let query = model.manualQuery.trimmingCharacters(in: .whitespaces)
        let entries: [(id: String, title: String)] = query.isEmpty
            ? document.chapters.map { ($0.id, $0.title) }
            : document.search(query).map { ($0.chapter.id, $0.chapter.title) }
        let half = (entries.count + 1) / 2
        return VStack(alignment: .leading, spacing: 6) {
            ManualSearchField(text: Binding(get: { model.manualQuery }, set: { model.manualQuery = $0 }))
            if entries.isEmpty {
                Text("No chapter mentions that.").font(.ui(.caption)).foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: 8) {
                ForEach([Array(entries.prefix(half)), Array(entries.dropFirst(half))], id: \.first?.id) { column in
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(column, id: \.id) { e in
                            row(title: e.title, detail: nil, selected: e.id == current) {
                                model.showChapter(e.id)
                                model.manualShowContents = false
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
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

struct PagerButton: View {
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
        var used = 2                                              // the chapter title
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
