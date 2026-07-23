import SwiftUI

struct LocalDataView: View {
    @ObservedObject var model: AppModel
    @State private var confirmsClear = false

    var body: some View {
        SettingsCard(title: "Dados locais", systemImage: "externaldrive.fill.badge.xmark", tint: .red) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Começar do zero")
                        .font(.headline)
                    Text("Remove pasta salva, histórico, checkpoint e outbox. O token será mantido.")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Limpar dados locais", role: .destructive, action: requestClear)
                    .disabled(model.isConnecting || model.isSyncing)
                    .confirmationDialog(
                        "Limpar os dados locais?",
                        isPresented: $confirmsClear,
                        titleVisibility: .visible
                    ) {
                        Button("Limpar dados locais", role: .destructive, action: model.clearLocalData)
                        Button("Cancelar", role: .cancel) {}
                    } message: {
                        Text("Esta ação não pode ser desfeita. O token do MarvelSnap.pro será mantido.")
                    }
            }
        }
    }

    private func requestClear() {
        confirmsClear = true
    }
}
