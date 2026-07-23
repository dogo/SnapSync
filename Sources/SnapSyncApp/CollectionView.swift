import SnapSyncCore
import SwiftUI

struct CollectionView: View {
    @ObservedObject var model: AppModel
    @State private var searchText = ""
    private let columns = [GridItem(.adaptive(minimum: 190))]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CollectionHeaderView(cardCount: model.cardCount, variantCount: model.variantCount)

                if filteredCards.isEmpty {
                    VStack {
                        Image(systemName: searchText.isEmpty ? "rectangle.stack.badge.questionmark" : "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text(searchText.isEmpty ? "Nenhuma carta encontrada" : "Nenhum resultado")
                            .font(.title2)
                            .bold()
                        Text(searchText.isEmpty ? "Selecione uma pasta válida do Marvel Snap nos Ajustes." : "Tente outro nome de carta.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    LazyVGrid(columns: columns) {
                        ForEach(filteredCards) { card in
                            CollectionCardView(card: card)
                        }
                    }
                }
            }
            .padding()
        }
        .background {
            LinearGradient(
                colors: [.purple.opacity(0.07), .pink.opacity(0.04), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
        .navigationTitle("Coleção")
        .searchable(text: $searchText, prompt: "Buscar carta")
    }

    private var filteredCards: [SnapSnapshot.OwnedCard] {
        let query = searchText.replacing(" ", with: "")
        guard query.isEmpty == false else { return model.collection }
        return model.collection.filter { $0.definitionID.localizedStandardContains(query) }
    }
}
