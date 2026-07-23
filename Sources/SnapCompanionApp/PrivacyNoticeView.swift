import SwiftUI

struct PrivacyNoticeView: View {
    var body: some View {
        SettingsCard(title: .privacyTitle, systemImage: "hand.raised.fill", tint: .green) {
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow(alignment: .firstTextBaseline) {
                    Image(systemName: "folder.fill")
                        .frame(width: 22)
                        .accessibilityHidden(true)
                    Text(.privacyLocalReadOnly)
                }
                GridRow(alignment: .firstTextBaseline) {
                    Image(systemName: "arrow.up.circle.fill")
                        .frame(width: 22)
                        .accessibilityHidden(true)
                    Text(.privacySyncScope)
                }
                GridRow(alignment: .firstTextBaseline) {
                    Image(systemName: "internaldrive.fill")
                        .frame(width: 22)
                        .accessibilityHidden(true)
                    Text(.privacyInventory)
                }
                GridRow(alignment: .firstTextBaseline) {
                    Image(systemName: "photo.fill")
                        .frame(width: 22)
                        .accessibilityHidden(true)
                    Text(.privacyImages)
                }
                GridRow(alignment: .firstTextBaseline) {
                    Image(systemName: "books.vertical.fill")
                        .frame(width: 22)
                        .accessibilityHidden(true)
                    Text(.privacyCatalog)
                }
                GridRow(alignment: .firstTextBaseline) {
                    Image(systemName: "eye.slash.fill")
                        .frame(width: 22)
                        .accessibilityHidden(true)
                    Text(.privacyNoTelemetry)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
