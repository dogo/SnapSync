import SwiftUI

struct InventorySummaryView: View {
    @ObservedObject var model: AppModel
    private let columns = [GridItem(.adaptive(minimum: 150))]

    var body: some View {
        VStack(alignment: .leading) {
            Label(.resources, systemImage: "wallet.pass.fill")
                .font(.title2)
                .bold()

            LazyVGrid(columns: columns) {
                MetricCard(title: .credits, value: formatted(model.credits), systemImage: "bolt.fill", tint: .blue)
                MetricCard(title: .gold, value: formatted(model.gold), systemImage: "circle.fill", tint: .yellow)
                MetricCard(
                    title: .tokens,
                    value: formatted(model.collectorsTokens),
                    systemImage: "hexagon.fill",
                    tint: .orange
                )
                MetricCard(
                    title: .wildBoosters,
                    value: formatted(model.wildBoosters),
                    systemImage: "sparkles",
                    tint: .purple
                )
                MetricCard(
                    title: .cardBoosters,
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
