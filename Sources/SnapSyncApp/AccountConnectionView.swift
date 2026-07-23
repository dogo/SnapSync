import SwiftUI

struct AccountConnectionView: View {
    @ObservedObject var model: AppModel
    @State private var confirmsDisconnect = false

    var body: some View {
        SettingsCard(title: "MarvelSnap.pro", systemImage: "link.circle.fill", tint: .purple) {
            HStack {
                VStack(alignment: .leading) {
                    Label(
                        model.isLinked ? "Conta vinculada" : "Conta não vinculada",
                        systemImage: model.isLinked ? "checkmark.seal.fill" : "person.crop.circle.badge.questionmark"
                    )
                    .font(.headline)

                    Text(
                        model.isLinked
                            ? "Coleção e decks podem ser sincronizados com segurança."
                            : "Vincule sua conta para começar a sincronizar."
                    )
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if model.isConnecting {
                    ProgressView()
                        .controlSize(.small)
                }

                if model.isLinked {
                    Button("Desconectar", role: .destructive, action: requestDisconnect)
                        .disabled(model.isConnecting || model.isSyncing)
                        .confirmationDialog(
                            "Desconectar do MarvelSnap.pro?",
                            isPresented: $confirmsDisconnect,
                            titleVisibility: .visible
                        ) {
                            Button("Desconectar", role: .destructive, action: model.disconnect)
                            Button("Cancelar", role: .cancel) {}
                        } message: {
                            Text("O token será removido do Keychain. Os dados locais serão mantidos.")
                        }
                } else {
                    Button("Conectar conta", systemImage: "link", action: connect)
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .disabled(model.canConnect == false || model.isConnecting || model.isSyncing)
                }
            }
        }
    }

    private func connect() {
        Task { await model.connect() }
    }

    private func requestDisconnect() {
        confirmsDisconnect = true
    }
}
