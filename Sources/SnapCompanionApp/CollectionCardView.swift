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

struct CardDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let card: CollectionCard

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    CollectionCardImageView(definitionID: card.id)
                        .grayscale(card.isOwned ? 0 : 1)
                        .opacity(card.isOwned ? 1 : 0.55)
                        .frame(maxWidth: 320)

                    if card.cost != nil || card.power != nil {
                        HStack(spacing: 28) {
                            if let cost = card.cost {
                                Label(cost.formatted(), systemImage: "hexagon.fill")
                                    .foregroundStyle(.blue)
                            }
                            if let power = card.power {
                                Label(power.formatted(), systemImage: "bolt.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .font(.title2)
                        .bold()
                    }

                    if let text = card.text {
                        Text(text)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 360)
                    }

                    if let ownedCard = card.ownedCard {
                        HStack(spacing: 28) {
                            Label(ownedCard.variants.count.formatted(), systemImage: "sparkles")
                                .help(Text(.variantsHelp))
                            Label((ownedCard.boosters ?? 0).formatted(), systemImage: "arrow.up.circle.fill")
                                .help(Text(.boostersHelp))
                        }
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    } else {
                        Label(.notOwned, systemImage: "lock.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .background {
                LinearGradient(
                    colors: [.purple.opacity(0.08), .pink.opacity(0.05), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
            .navigationTitle(card.name)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: dismiss.callAsFunction) {
                        Text(.close)
                    }
                }
            }
        }
        .frame(minWidth: 460, minHeight: 620)
    }
}
