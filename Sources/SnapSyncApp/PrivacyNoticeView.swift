import SwiftUI

struct PrivacyNoticeView: View {
    var body: some View {
        SettingsCard(title: "Privacidade", systemImage: "hand.raised.fill", tint: .green) {
            VStack(alignment: .leading) {
                Label("Leitura local e somente leitura dos arquivos do Marvel Snap.", systemImage: "folder.fill")
                Label("Conta, coleção e decks são enviados somente ao MarvelSnap.pro.", systemImage: "arrow.up.circle.fill")
                Label("Inventário e histórico permanecem somente neste Mac.", systemImage: "internaldrive.fill")
                Label("Sem analytics ou telemetria.", systemImage: "eye.slash.fill")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
