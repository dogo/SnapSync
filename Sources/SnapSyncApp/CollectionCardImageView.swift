import Kingfisher
import SwiftUI

struct CollectionCardImageView: View {
    let definitionID: String

    var body: some View {
        KFImage(URL(string: "https://static.marvelsnap.pro/cards/\(definitionID).webp"))
            .placeholder {
                ZStack {
                    LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                }
            }
            .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 300, height: 300)))
            .cancelOnDisappear(true)
            .resizable()
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(.rect(cornerRadius: 12))
            .accessibilityHidden(true)
    }
}
