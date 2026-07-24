import SnapSyncCore
import SwiftUI

struct MatchOverlayView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Label("Opponent", systemImage: "person.fill")
                    .font(.headline)
                Spacer()
                Button {
                    model.toggleOverlay()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(.overlayHide))
            }

            if model.opponentCards.isEmpty {
                Text("Waiting for the opponent to reveal cards…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Revealed \(model.opponentCards.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(Array(model.opponentCards.enumerated()), id: \.offset) { _, id in
                        CollectionCardImageView(definitionID: id)
                            .frame(width: 46, height: 46)
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 300, alignment: .leading)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.12)))
    }

    private let columns = [GridItem(.adaptive(minimum: 46), spacing: 6)]
}
