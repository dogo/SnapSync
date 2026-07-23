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
                    Text("Sua coleção")
                        .font(.title)
                        .bold()
                    Text("Explore as cartas possuídas e descubra quais ainda faltam.")
                        .foregroundStyle(.white.opacity(0.85))
                    if let totalCount {
                        Text("\(ownedCount.formatted()) possuídas de \(totalCount.formatted()) · ^[\(variantCount) variante](inflect: true)")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                    } else {
                        Text("^[\(ownedCount) carta](inflect: true) · ^[\(variantCount) variante](inflect: true)")
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
