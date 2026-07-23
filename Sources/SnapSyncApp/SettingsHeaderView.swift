import SwiftUI

struct SettingsHeaderView: View {
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 130))
                .foregroundStyle(.white.opacity(0.08))
                .offset(x: 28, y: -38)
                .accessibilityHidden(true)

            HStack {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .shadow(radius: 8)
                    .accessibilityHidden(true)

                VStack(alignment: .leading) {
                    Text(.settingsHeaderTitle)
                        .font(.title)
                        .bold()
                    Text(.settingsHeaderSubtitle)
                        .foregroundStyle(.white.opacity(0.85))
                    Label(.keychainProtected, systemImage: "lock.fill")
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
        .shadow(color: .purple.opacity(0.22), radius: 16, y: 8)
        .accessibilityElement(children: .combine)
    }
}
