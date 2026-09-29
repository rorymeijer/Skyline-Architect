import SwiftUI

/// The building's foundation and the ways to grow it (0.21): wider within the plot, deeper
/// basements, longer piles (which carry more storeys). Every button is one undoable step.
struct FoundationPanel: View {
    let model: AppModel

    var body: some View {
        if let f = model.foundation {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Foundation").font(.ui(.headline))
                    Spacer()
                    CloseButton { model.showFoundationPanel = false }
                }
                Text(f.building).font(.ui(.caption)).foregroundStyle(.secondary)
                Text("\(f.widthMeters) m wide · \(f.basements) of \(f.maxBasements) basement level\(f.maxBasements == 1 ? "" : "s") · piles \(f.pileDepth) m")
                    .font(.ui(.caption).monospacedDigit())
                if let carries = f.carries {
                    Text("The piles carry \(carries) storeys; \(f.built) built.").font(.ui(.caption).monospacedDigit())
                        .foregroundStyle(f.built >= carries ? Color.orange : Color.secondary)
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 6) {
                    ForEach(f.options) { o in
                        Button { if let c = o.command { model.perform(c) } } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Label(o.title, systemImage: o.symbol).font(.ui(.caption).weight(.semibold))
                                Text(o.detail).font(.ui(.caption2).monospacedDigit()).foregroundStyle(.secondary).lineLimit(2)
                            }
                            .padding(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(o.command == nil ? 0.04 : 0.12)))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(o.command == nil)
                        .opacity(o.command == nil ? 0.55 : 1)
                        .help(o.detail)
                        .accessibilityLabel(o.title)
                        .accessibilityValue(o.detail)
                    }
                }
            }
            .padding(12)
            .scaledFrame(width: 320, alignment: .leading)
            .panelCard()
            .environment(\.colorScheme, .dark)
        }
    }
}
