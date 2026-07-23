import SwiftUI

struct DashboardView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text("Marvel Snap Sync")
                    .font(.largeTitle)
                    .bold()

                GroupBox("Status") {
                    Label(
                        model.statusText,
                        systemImage: model.isSyncing || model.isConnecting
                            ? "arrow.triangle.2.circlepath"
                            : model.hasError ? "exclamationmark.triangle" : "checkmark.circle"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Dados encontrados") {
                    VStack(alignment: .leading) {
                        LabeledContent("Conta", value: model.accountName)
                        LabeledContent("Coleção", value: "\(model.cardCount) cartas · \(model.variantCount) variantes")
                        LabeledContent("Decks", value: "\(model.deckCount)")
                        LabeledContent("Pasta") {
                            Text(model.sourcePath)
                                .lineLimit(2)
                                .textSelection(.enabled)
                        }
                    }
                }

                InventorySummaryView(model: model)

                SnapshotChangesView(change: model.lastChange)

                AccountConnectionView(model: model)

                PrivacyNoticeView()

                LocalDataView(model: model)

                Toggle("Sincronizar automaticamente ao detectar mudanças", isOn: $model.automaticSyncEnabled)

                HStack {
                    if model.isSyncing {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Button("Escolher pasta…", action: chooseFolder)
                        .disabled(model.isSyncing || model.isConnecting)
                    Spacer()
                    Button("Sincronizar agora", action: synchronize)
                        .buttonStyle(.borderedProminent)
                        .disabled(model.canSync == false || model.isSyncing || model.isConnecting)
                }
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 680)
    }

    private func synchronize() {
        Task { await model.synchronize() }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Selecione a pasta nvprod do Marvel Snap."
        panel.prompt = "Selecionar"
        if panel.runModal() == .OK, let url = panel.url {
            model.selectFolder(url)
        }
    }
}
