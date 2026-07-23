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
                        Label(.missing, systemImage: "lock.fill")
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
                        .help(Text(.variantsHelp))
                    Spacer()
                    Label((ownedCard.boosters ?? 0).formatted(), systemImage: "arrow.up.circle.fill")
                        .help(Text(.boostersHelp))
                }
                .foregroundStyle(.secondary)
            } else {
                Label(.notOwned, systemImage: "lock.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .shadow(color: .purple.opacity(0.1), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(accessibilityLabel))
    }

    private var accessibilityLabel: LocalizedStringResource {
        if let ownedCard = card.ownedCard {
            .collectionOwnedAccessibility(card.name, ownedCard.variants.count, ownedCard.boosters ?? 0)
        } else {
            .collectionMissingAccessibility(card.name)
        }
    }
}
