import SnapSyncCore
import SwiftUI

struct CollectionCardView: View {
    let card: CollectionCard

    var body: some View {
        VStack(alignment: .leading) {
            CollectionCardImageView(definitionID: card.id)
                .grayscale(card.isOwned ? 0 : 1)
                .opacity(card.isOwned ? 1 : 0.55)
                .overlay(alignment: .topTrailing) {
                    if card.isOwned == false {
                        Label("Faltando", systemImage: "lock.fill")
                            .font(.caption)
                            .padding(6)
                            .background(.regularMaterial, in: .capsule)
                            .padding(6)
                    }
                }

            Text(card.name)
                .font(.headline)
                .lineLimit(2)

            Divider()

            if let ownedCard = card.ownedCard {
                HStack {
                    Label(ownedCard.variants.count.formatted(), systemImage: "sparkles")
                        .help("Variantes")
                    Spacer()
                    Label((ownedCard.boosters ?? 0).formatted(), systemImage: "arrow.up.circle.fill")
                        .help("Boosters")
                }
                .foregroundStyle(.secondary)
            } else {
                Label("Não possuída", systemImage: "lock.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .shadow(color: .purple.opacity(0.1), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if let ownedCard = card.ownedCard {
            "\(card.name), possuída, \(ownedCard.variants.count) variantes, \(ownedCard.boosters ?? 0) boosters"
        } else {
            "\(card.name), não possuída"
        }
    }
}
