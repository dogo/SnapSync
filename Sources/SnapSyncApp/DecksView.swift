import SnapSyncCore
import SwiftUI

struct DecksView: View {
    @ObservedObject var model: AppModel
    @State private var searchText = ""
    @State private var selectedDeck: SnapSnapshot.Deck?
    private let columns = [GridItem(.adaptive(minimum: 270))]

    var body: some View {
        let decks = searchText.isEmpty
            ? model.decks
            : model.decks.filter { $0.name.localizedStandardContains(searchText) }

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DecksHeaderView(deckCount: model.deckCount)

                if decks.isEmpty {
                    VStack {
                        Image(systemName: searchText.isEmpty ? "rectangle.stack.badge.questionmark" : "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text(model.decks.isEmpty ? "Nenhum deck encontrado" : "Nenhum resultado")
                            .font(.title2)
                            .bold()
                        Text(model.decks.isEmpty ? "Selecione uma pasta válida do Marvel Snap nos Ajustes." : "Tente outro nome de deck.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    LazyVGrid(columns: columns) {
                        ForEach(decks) { deck in
                            Button {
                                selectedDeck = deck
                            } label: {
                                DeckPreviewCard(deck: deck)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(deck.name), \(deck.cardDefinitionIDs.count) cartas")
                            .accessibilityHint("Abre o conteúdo do deck")
                        }
                    }
                }
            }
            .padding()
        }
        .background {
            LinearGradient(
                colors: [.blue.opacity(0.08), .purple.opacity(0.05), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
        .navigationTitle("Decks")
        .searchable(text: $searchText, prompt: "Buscar deck")
        .sheet(item: $selectedDeck) { deck in
            DeckDetailView(deck: deck)
        }
    }
}

private struct DecksHeaderView: View {
    let deckCount: Int

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 130))
                .foregroundStyle(.white.opacity(0.08))
                .offset(x: 28, y: -38)
                .accessibilityHidden(true)

            HStack {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.largeTitle)
                    .accessibilityHidden(true)

                VStack(alignment: .leading) {
                    Text("Seus decks")
                        .font(.title)
                        .bold()
                    Text("Abra um deck para conferir suas cartas.")
                        .foregroundStyle(.white.opacity(0.85))
                    Text("^[\(deckCount) deck](inflect: true)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }

                Spacer()
            }
            .padding()
        }
        .foregroundStyle(.white)
        .background {
            LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .clipShape(.rect(cornerRadius: 20))
        .shadow(color: .blue.opacity(0.22), radius: 16, y: 8)
        .accessibilityElement(children: .combine)
    }
}

private struct DeckPreviewCard: View {
    let deck: SnapSnapshot.Deck

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if deck.cardDefinitionIDs.isEmpty {
                Image(systemName: "rectangle.stack.badge.questionmark")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 92)
                    .accessibilityHidden(true)
            } else {
                HStack(spacing: -18) {
                    ForEach(Array(deck.cardDefinitionIDs.prefix(4).enumerated()), id: \.offset) { index, definitionID in
                        CollectionCardImageView(definitionID: definitionID)
                            .frame(width: 78, height: 78)
                            .shadow(color: .black.opacity(0.25), radius: 5, y: 3)
                            .zIndex(Double(index))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 92)
            }

            Text(deck.name)
                .font(.headline)
                .lineLimit(2)

            Label("^[\(deck.cardDefinitionIDs.count) carta](inflect: true)", systemImage: "rectangle.stack.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .shadow(color: .blue.opacity(0.1), radius: 8, y: 4)
        .contentShape(.rect(cornerRadius: 16))
    }
}

private struct DeckDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let deck: SnapSnapshot.Deck
    private let columns = [GridItem(.adaptive(minimum: 150))]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns) {
                    ForEach(deck.cardDefinitionIDs, id: \.self) { definitionID in
                        VStack(alignment: .leading) {
                            CollectionCardImageView(definitionID: definitionID)
                            Text(displayName(for: definitionID))
                                .font(.headline)
                                .lineLimit(2)
                        }
                        .padding()
                        .background(.regularMaterial, in: .rect(cornerRadius: 16))
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding()
            }
            .background {
                LinearGradient(
                    colors: [.purple.opacity(0.08), .blue.opacity(0.05), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
            .navigationTitle(deck.name)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
        .frame(minWidth: 720, minHeight: 620)
    }

    private func displayName(for definitionID: String) -> String {
        definitionID.replacing(/([a-z0-9])([A-Z])/) { match in
            "\(match.1) \(match.2)"
        }
    }
}
