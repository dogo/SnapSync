import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Label(model.statusText, systemImage: statusImage)

        Divider()

        Button(action: synchronize) {
            Text(.syncNow)
        }
        .disabled(model.canSync == false || model.isSyncing || model.isConnecting)

        Toggle(isOn: $model.automaticSyncEnabled) {
            Text(.automaticSync)
        }

        Button(action: openDashboard) {
            Text(.openWindow)
        }

        Divider()

        Button(action: quit) {
            Text(.quit)
        }
    }

    private var statusImage: String {
        if model.isSyncing || model.isConnecting {
            "arrow.triangle.2.circlepath"
        } else if model.hasError {
            "exclamationmark.triangle"
        } else {
            "checkmark.circle"
        }
    }

    private func synchronize() {
        Task { await model.synchronize() }
    }

    private func openDashboard() {
        openWindow(id: "dashboard")
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
