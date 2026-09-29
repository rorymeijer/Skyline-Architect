import SwiftUI
import SkylineContent

/// The manual (F3): chapters on the left with a search field, the chapter on the right.
/// Links to other chapters (`transport.md`) open them in place.
struct ManualView: View {
    let model: AppModel

    var body: some View {
        let document = model.manual?.document ?? ManualDocument(chapters: [])
        let chapter = model.manualChapterID.flatMap { document.chapter($0) } ?? document.chapters.first
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
                .onTapGesture { model.showManual = false }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Manual", systemImage: "book").font(.title2.weight(.bold))
                    Spacer()
                    CloseButton { model.showManual = false }
                        .keyboardShortcut(.cancelAction)
                }
                HStack(alignment: .top, spacing: 14) {
                    sidebar(document, current: chapter?.id)
                        .frame(width: 220)
                    ScrollView {
                        if let chapter {
                            ManualChapterView(chapter: chapter).padding(.trailing, 8)
                        } else {
                            Text("The manual is missing from this build.").foregroundStyle(.secondary)
                        }
                    }
                    .id(chapter?.id)                                      // a new chapter starts at the top
                    .environment(\.openURL, OpenURLAction { url in
                        guard url.pathExtension == "md" else { return .systemAction }
                        model.manualChapterID = url.deletingPathExtension().lastPathComponent
                        return .handled
                    })
                }
            }
            .padding(20)
            .frame(maxWidth: 860, maxHeight: 600)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .padding(24)
        }
        .environment(\.colorScheme, .dark)
    }

    private func sidebar(_ document: ManualDocument, current: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Search", text: Binding(get: { model.manualQuery }, set: { model.manualQuery = $0 }))
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Search the manual")
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if model.manualQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                        ForEach(document.chapters) { c in
                            row(title: c.title, detail: nil, selected: c.id == current) { model.manualChapterID = c.id }
                        }
                    } else {
                        let hits = document.search(model.manualQuery)
                        if hits.isEmpty {
                            Text("No chapter mentions that.").font(.caption).foregroundStyle(.secondary).padding(6)
                        }
                        ForEach(hits, id: \.chapter.id) { hit in
                            row(title: hit.chapter.title, detail: hit.snippet, selected: hit.chapter.id == current) {
                                model.manualChapterID = hit.chapter.id
                            }
                        }
                    }
                }
            }
        }
    }

    private func row(title: String, detail: String?, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(selected ? .semibold : .regular))
                if let detail {
                    Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(selected ? 0.2 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// One chapter's blocks, rendered natively (inline Markdown via `AttributedString`).
struct ManualChapterView: View {
    let chapter: ManualChapter

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(chapter.title).font(.title.weight(.bold)).accessibilityAddTraits(.isHeader)
            ForEach(Array(chapter.blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func blockView(_ block: ManualBlock) -> some View {
        switch block {
        case let .heading(level, text):
            Text(Self.inline(text)).font(level <= 2 ? .title3.weight(.semibold) : .headline)
                .padding(.top, level <= 2 ? 6 : 2)
                .accessibilityAddTraits(.isHeader)
        case let .paragraph(text):
            Text(Self.inline(text)).font(.body).fixedSize(horizontal: false, vertical: true)
        case let .bullets(items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("•")
                        Text(Self.inline(item)).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        case let .numbered(items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(i + 1).").monospacedDigit()
                        Text(Self.inline(item)).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        case let .note(text):
            Label { Text(Self.inline(text)).fixedSize(horizontal: false, vertical: true) } icon: { Image(systemName: "lightbulb") }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.yellow.opacity(0.12)))
        case let .table(header, rows):
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 4) {
                GridRow { ForEach(Array(header.enumerated()), id: \.offset) { _, h in Text(Self.inline(h)).font(.caption.weight(.semibold)) } }
                Divider()
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow { ForEach(Array(row.enumerated()), id: \.offset) { _, cell in Text(Self.inline(cell)).font(.callout) } }
                }
            }
        }
    }

    static func inline(_ markdown: String) -> AttributedString {
        (try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(markdown)
    }
}

/// The tutorial scenario's guide (F3): the step to do now, with the list of steps.
struct TutorialPanel: View {
    let model: AppModel
    let tutorial: TutorialSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Tutorial", systemImage: "graduationcap").font(.headline)
                Spacer()
                Text("\(tutorial.progress.completed) of \(tutorial.steps.count)")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                CloseButton { model.showTutorialPanel = false }
            }
            ProgressView(value: Double(tutorial.progress.completed), total: Double(max(tutorial.steps.count, 1)))
                .accessibilityLabel("Tutorial progress")
            if let step = tutorial.current {
                Text(step.title).font(.callout.weight(.semibold))
                Text(ManualChapterView.inline(step.text)).font(.callout).fixedSize(horizontal: false, vertical: true)
                if let chapter = step.chapter {
                    Button("Read more in the manual") { model.openManual(chapter: chapter) }
                        .buttonStyle(.borderless).font(.caption)
                }
            } else {
                Text("Every step done. Keep the units let through a closing to finish.")
                    .font(.callout).fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(tutorial.steps.enumerated()), id: \.element.id) { i, step in
                    let done = tutorial.progress.done[i]
                    let now = i == tutorial.progress.current
                    Label(step.title, systemImage: done ? "checkmark.circle.fill" : (now ? "arrow.right.circle" : "circle"))
                        .font(.caption.weight(now ? .semibold : .regular))
                        .foregroundStyle(done ? Color.green : (now ? Color.primary : Color.secondary))
                        .accessibilityValue(done ? "Done" : (now ? "Current step" : "To do"))
                }
            }
        }
        .padding(12)
        .frame(width: 290, alignment: .leading)
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
                Label(hint.title, systemImage: "lightbulb").font(.callout.weight(.semibold))
                Spacer()
                CloseButton { model.dismissHint() }
            }
            Text(ManualChapterView.inline(hint.text)).font(.callout).fixedSize(horizontal: false, vertical: true)
            HStack {
                if let chapter = hint.chapter {
                    Button("Read more") {
                        model.dismissHint()
                        model.openManual(chapter: chapter)
                    }
                    .buttonStyle(.borderless)
                }
                Spacer()
                Button("Turn off tips") { model.setHintsEnabled(false) }.buttonStyle(.borderless).foregroundStyle(.secondary)
                Button("Got it") { model.dismissHint() }.buttonStyle(.borderedProminent).controlSize(.small)
            }
            .font(.caption)
        }
        .padding(12)
        .frame(width: 360, alignment: .leading)
        .panelCard()
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tip: \(hint.title)")
    }
}
