import SwiftUI

@main
struct SnapSyncApplication: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("SnapSync", id: "dashboard") {
            DashboardView(model: model)
                .task { model.load() }
        }

        MenuBarExtra("SnapSync", systemImage: "arrow.triangle.2.circlepath") {
            MenuBarContentView(model: model)
        }
    }
}
