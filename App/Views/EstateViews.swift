import SwiftUI
import SkylineContent
import SkylineCore
import SkylinePresentation

/// Owned properties across cities, switching between them, and land for sale (⌥⌘K).
struct EstatePanel: View {
    let model: AppModel

    var body: some View {
        let s = model.estate
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Estate").font(.headline)
                Spacer()
                CloseButton { model.showEstatePanel = false }
            }
            Text("\(s.holdings.count) propert\(s.holdings.count == 1 ? "y" : "ies") in \(s.cities) cit\(s.cities == 1 ? "y" : "ies") · one account: \(Money.format(s.cash))")
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            Text("Last 24 h \(Money.format(s.totalNet24h)): buildings \(Money.format(s.totalNet24h - s.estateNet24h)) · estate \(Money.format(s.estateNet24h))")
                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                .help("Estate: money not booked to a building — loans, interest, land and grants.")
            ForEach(s.holdings, id: \.property) { h in
                let active = h.property == model.activePropertyID
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(h.name) · \(h.city)" + (h.weather.isEmpty ? "" : " · \(h.weather)")).font(.caption.weight(.semibold))
                        Text("\(h.floors) floors · \(h.tenants)/\(h.units) let · \(h.population) people · \(h.className) \(h.reputation)")
                            .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                        Text("24 h: \(Money.format(h.net24h))").font(.caption2.monospacedDigit())
                            .foregroundStyle(h.net24h < 0 ? Color.orange : Color.green)
                    }
                    Spacer()
                    if active {
                        Text("Viewing").font(.caption2).foregroundStyle(.secondary)
                    } else {
                        PanelButton(title: "Go") { model.switchProperty(h.property) }
                    }
                }
            }
            if !s.offers.isEmpty {
                Divider()
                Text("Land for sale").font(.caption.weight(.semibold))
                ForEach(s.offers, id: \.plotID) { o in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(o.name) · \(o.city)").font(.caption)
                            Text("\(o.frontage) m frontage · \(o.basements) basement levels · \(o.market)")
                                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        PanelButton(title: "Buy \(Money.format(o.price))", enabled: o.affordable) { model.buyPlot(o.plotID) }
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 360, alignment: .leading)
        .panelCard()
        .environment(\.colorScheme, .dark)
    }
}
