import SnapSyncCore
import SwiftUI

struct SnapshotChangesView: View {
    let change: SnapshotHistoryStore.Change?

    var body: some View {
        VStack(alignment: .leading) {
            Label(.historyTitle, systemImage: "clock.arrow.circlepath")
                .font(.title2)
                .bold()

            Group {
                if let change {
                    HStack {
                        LabeledContent {
                            Text(change.newCards.formatted())
                        } label: {
                            Text(.historyNewCards)
                        }
                        Divider()
                        LabeledContent {
                            Text(change.newVariants.formatted())
                        } label: {
                            Text(.historyNewVariants)
                        }
                        Divider()
                        LabeledContent {
                            Text(change.changedDecks.formatted())
                        } label: {
                            Text(.historyChangedDecks)
                        }
                    }

                    Text(change.observedAt, format: .dateTime.day().month().year().hour().minute())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Label(.historyWaiting, systemImage: "sparkles")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.regularMaterial, in: .rect(cornerRadius: 16))
        }
    }
}
