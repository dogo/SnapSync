import SwiftUI

struct CollectionHeaderView: View {
    let ownedCount: Int
    let totalCount: Int?
    let variantCount: Int

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 130))
                .foregroundStyle(.white.opacity(0.08))
                .offset(x: 28, y: -38)
                .accessibilityHidden(true)

            HStack {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.largeTitle)
                    .accessibilityHidden(true)

                VStack(alignment: .leading) {
                    Text(.collectionHeaderTitle)
                        .font(.title)
                        .bold()
                    Text(.collectionHeaderSubtitle)
                        .foregroundStyle(.white.opacity(0.85))
                    if let totalCount {
                        Text(.collectionOwnedProgress(ownedCount, totalCount, variantCount))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                    } else {
                        Text(.collectionSummary(ownedCount, variantCount))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }

                Spacer()
            }
            .padding()
        }
        .foregroundStyle(.white)
        .background {
            LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .clipShape(.rect(cornerRadius: 20))
        .shadow(color: .purple.opacity(0.22), radius: 16, y: 8)
        .accessibilityElement(children: .combine)
    }
}
