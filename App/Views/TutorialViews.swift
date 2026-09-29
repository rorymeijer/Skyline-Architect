import SwiftUI
import SkylineContent

/// The tutorial scenario's guide (F3): the step to do now, with the list of steps.
struct TutorialPanel: View {
    let model: AppModel
    let tutorial: TutorialSummary

    var body: some View {
        // Where the step list does not fit (F5, an iPhone), the panel shows the current step only,
        // and if that is still too tall, in smaller type on a wider card.
        ViewThatFits(in: .vertical) {
            content(list: true)
            content(list: false)
            content(list: false, small: true)
        }
    }

    private func content(list: Bool, small: Bool = false) -> some View {
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
                Text(ManualPageView.inline(step.text)).font(.ui(small ? .footnote : .callout)).fixedSize(horizontal: false, vertical: true)
                if let chapter = step.chapter {
                    LinkButton(title: "Read more in the manual") { model.openManual(chapter: chapter) }
                }
            } else {
                Text("Every step done. Keep the units let through a closing to finish.")
                    .font(.ui(.callout)).fixedSize(horizontal: false, vertical: true)
            }
            if list {
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
        }
        .padding(12)
        .scaledFrame(width: small ? 340 : 290, alignment: .leading)
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
struct LinkButton: View {
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
