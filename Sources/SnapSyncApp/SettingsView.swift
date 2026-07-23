import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsHeaderView()

                SettingsCard(title: "Sincronização", systemImage: "bolt.horizontal.circle.fill", tint: .blue) {
                    Toggle(
                        "Sincronizar automaticamente ao detectar mudanças",
                        isOn: $model.automaticSyncEnabled
                    )
                    .toggleStyle(.switch)

                    Text("Quando o Marvel Snap alterar sua coleção ou seus decks, o envio acontece automaticamente.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Divider()

                    Label("Pasta do Marvel Snap", systemImage: "folder.fill")
                        .font(.headline)

                    Text(model.sourcePath)
                        .font(.callout.monospaced())
                        .lineLimit(2)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.quaternary, in: .rect(cornerRadius: 10))

                    HStack {
                        Label(
                            model.canConnect ? "Fonte de dados ativa" : "Pasta ainda não configurada",
                            systemImage: model.canConnect ? "checkmark.circle.fill" : "exclamationmark.circle"
                        )
                        .foregroundStyle(.secondary)

                        Spacer()

                        Button(
                            model.canConnect ? "Alterar pasta…" : "Escolher pasta…",
                            systemImage: "folder.badge.gearshape",
                            action: chooseFolder
                        )
                        .disabled(model.isSyncing || model.isConnecting)
                    }
                }

                AccountConnectionView(model: model)
                PrivacyNoticeView()
                LocalDataView(model: model)
            }
            .padding()
        }
        .background {
            LinearGradient(
                colors: [.blue.opacity(0.06), .purple.opacity(0.05), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
        .navigationTitle("Ajustes")
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
