import SwiftUI

struct PrivacyNoticeView: View {
    var body: some View {
        SettingsCard(title: "Privacidade", systemImage: "hand.raised.fill", tint: .green) {
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow(alignment: .firstTextBaseline) {
                    Image(systemName: "folder.fill")
                        .frame(width: 22)
                        .accessibilityHidden(true)
                    Text("Leitura local e somente leitura dos arquivos do Marvel Snap.")
                }
                GridRow(alignment: .firstTextBaseline) {
                    Image(systemName: "arrow.up.circle.fill")
                        .frame(width: 22)
                        .accessibilityHidden(true)
                    Text("Conta, coleção e decks são enviados somente ao MarvelSnap.pro.")
                }
                GridRow(alignment: .firstTextBaseline) {
                    Image(systemName: "internaldrive.fill")
                        .frame(width: 22)
                        .accessibilityHidden(true)
                    Text("Inventário e histórico permanecem somente neste Mac.")
                }
                GridRow(alignment: .firstTextBaseline) {
                    Image(systemName: "eye.slash.fill")
                        .frame(width: 22)
                        .accessibilityHidden(true)
                    Text("Sem analytics ou telemetria.")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
