import SwiftUI

struct PrivacyNoticeView: View {
    var body: some View {
        GroupBox("Privacidade") {
            VStack(alignment: .leading) {
                Label("Leitura local e somente leitura dos arquivos do Marvel Snap.", systemImage: "folder")
                Label("Conta, coleção e decks são enviados somente ao MarvelSnap.pro.", systemImage: "arrow.up.circle")
                Label("Inventário e histórico permanecem somente neste Mac.", systemImage: "internaldrive")
                Label("Token protegido no Keychain; sem analytics ou telemetria.", systemImage: "lock")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
