import SnapSyncCore
import SwiftUI

struct SnapshotChangesView: View {
    let change: SnapshotHistoryStore.Change?

    var body: some View {
        VStack(alignment: .leading) {
            Label("Últimas mudanças", systemImage: "clock.arrow.circlepath")
                .font(.title2)
                .bold()

            Group {
                if let change {
                    HStack {
                        LabeledContent("Cartas novas", value: change.newCards.formatted())
                        Divider()
                        LabeledContent("Variantes novas", value: change.newVariants.formatted())
                        Divider()
                        LabeledContent("Decks alterados", value: change.changedDecks.formatted())
                    }

                    Text(change.observedAt, format: .dateTime.day().month().year().hour().minute())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Label("Aguardando a próxima mudança na coleção ou nos decks.", systemImage: "sparkles")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.regularMaterial, in: .rect(cornerRadius: 16))
        }
    }
}
