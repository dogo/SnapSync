import SwiftUI

struct AccountConnectionView: View {
    @ObservedObject var model: AppModel
    @State private var confirmsDisconnect = false

    var body: some View {
        GroupBox("MarvelSnap.pro") {
            HStack {
                Label(
                    model.isLinked ? "Conta vinculada" : "Conta não vinculada",
                    systemImage: model.isLinked ? "checkmark.circle" : "link"
                )

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
                    Button("Conectar conta", action: connect)
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
