import SwiftUI

struct SyncStatusCard: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 140))
                .foregroundStyle(.white.opacity(0.08))
                .offset(x: 32, y: -36)
                .accessibilityHidden(true)

            HStack {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 72, height: 72)
                    .shadow(radius: 8)
                    .accessibilityHidden(true)

                VStack(alignment: .leading) {
                    Label(model.statusText, systemImage: statusImage)
                        .font(.title2)
                        .bold()

                    Text(model.accountName)
                        .foregroundStyle(.white.opacity(0.85))

                    Label {
                        Text(model.automaticSyncEnabled ? .automaticSync : .manualSync)
                    } icon: {
                        Image(systemName: model.automaticSyncEnabled ? "bolt.fill" : "hand.tap.fill")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                }

                Spacer()

                if model.isSyncing || model.isConnecting {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                }
            }
            .padding()
        }
        .foregroundStyle(.white)
        .background {
            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .clipShape(.rect(cornerRadius: 20))
        .shadow(color: gradientColors.last?.opacity(0.25) ?? .clear, radius: 16, y: 8)
        .accessibilityElement(children: .combine)
    }

    private var gradientColors: [Color] {
        if model.hasError {
            [.orange, .red]
        } else {
            [.purple, .blue]
        }
    }

    private var statusImage: String {
        if model.isSyncing || model.isConnecting {
            "arrow.triangle.2.circlepath"
        } else if model.hasError {
            "exclamationmark.triangle.fill"
        } else {
            "checkmark.seal.fill"
        }
    }
}
