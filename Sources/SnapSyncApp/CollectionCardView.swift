import SnapSyncCore
import SwiftUI

struct CollectionCardView: View {
    let card: SnapSnapshot.OwnedCard

    var body: some View {
        VStack(alignment: .leading) {
            CollectionCardImageView(definitionID: card.definitionID)

            Text(displayName)
                .font(.headline)
                .lineLimit(2)

            Divider()

            HStack {
                Label(card.variants.count.formatted(), systemImage: "sparkles")
                    .help("Variantes")
                Spacer()
                Label((card.boosters ?? 0).formatted(), systemImage: "arrow.up.circle.fill")
                    .help("Boosters")
            }
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .shadow(color: .purple.opacity(0.1), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(displayName), \(card.variants.count) variantes, \(card.boosters ?? 0) boosters"
        )
    }

    private var displayName: String {
        card.definitionID.replacing(/([a-z0-9])([A-Z])/) { match in
            "\(match.1) \(match.2)"
        }
    }
}
