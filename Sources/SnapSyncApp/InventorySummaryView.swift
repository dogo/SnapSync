import SwiftUI

struct InventorySummaryView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        GroupBox("Inventário") {
            VStack(alignment: .leading) {
                LabeledContent("Nível da coleção", value: formatted(model.collectionLevel))
                LabeledContent("Créditos", value: formatted(model.credits))
                LabeledContent("Ouro", value: formatted(model.gold))
                LabeledContent("Tokens do Colecionador", value: formatted(model.collectorsTokens))
                LabeledContent("Boosters curingas", value: formatted(model.wildBoosters))
                LabeledContent("Boosters de cartas", value: model.boosterCount.formatted())
            }
        }
    }

    private func formatted(_ value: Int?) -> String {
        value?.formatted() ?? "—"
    }
}
