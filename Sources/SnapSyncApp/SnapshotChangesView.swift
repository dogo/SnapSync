import SnapSyncCore
import SwiftUI

struct SnapshotChangesView: View {
    let change: SnapshotHistoryStore.Change?

    var body: some View {
        GroupBox("Últimas mudanças") {
            if let change {
                VStack(alignment: .leading) {
                    LabeledContent("Cartas novas", value: change.newCards.formatted())
                    LabeledContent("Variantes novas", value: change.newVariants.formatted())
                    LabeledContent("Decks alterados", value: change.changedDecks.formatted())
                    LabeledContent(
                        "Detectadas",
                        value: change.observedAt.formatted(date: .abbreviated, time: .shortened)
                    )
                }
            } else {
                Label("Aguardando a próxima mudança na coleção ou nos decks.", systemImage: "clock")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
