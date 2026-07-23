import SwiftUI

struct InventorySummaryView: View {
    @ObservedObject var model: AppModel
    private let columns = [GridItem(.adaptive(minimum: 150))]

    var body: some View {
        VStack(alignment: .leading) {
            Label("Recursos", systemImage: "wallet.pass.fill")
                .font(.title2)
                .bold()

            LazyVGrid(columns: columns) {
                MetricCard(title: "Créditos", value: formatted(model.credits), systemImage: "bolt.fill", tint: .blue)
                MetricCard(title: "Ouro", value: formatted(model.gold), systemImage: "circle.fill", tint: .yellow)
                MetricCard(
                    title: "Tokens",
                    value: formatted(model.collectorsTokens),
                    systemImage: "hexagon.fill",
                    tint: .orange
                )
                MetricCard(
                    title: "Boosters curingas",
                    value: formatted(model.wildBoosters),
                    systemImage: "sparkles",
                    tint: .purple
                )
                MetricCard(
                    title: "Boosters de cartas",
                    value: model.boosterCount.formatted(),
                    systemImage: "arrow.up.circle.fill",
                    tint: .pink
                )
            }
        }
    }

    private func formatted(_ value: Int?) -> String {
        value?.formatted() ?? "—"
    }
}
