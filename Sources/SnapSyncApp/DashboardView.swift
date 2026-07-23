import SwiftUI

struct DashboardView: View {
    @ObservedObject var model: AppModel
    @State private var selection: DashboardSection? = .overview

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .frame(width: 40, height: 40)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading) {
                        Text("SnapSync")
                            .font(.headline)
                        Text("Marvel Snap companion")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding()

                Divider()

                List(DashboardSection.allCases, selection: $selection) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210)
        } detail: {
            Group {
                switch selection ?? .overview {
                case .overview:
                    OverviewView(model: model)
                case .collection:
                    CollectionView(model: model)
                case .decks:
                    DecksView(model: model)
                case .settings:
                    SettingsView(model: model)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Sincronizar agora", systemImage: "arrow.triangle.2.circlepath", action: synchronize)
                        .disabled(model.canSync == false || model.isSyncing || model.isConnecting)
                }
            }
        }
        .frame(minWidth: 760, minHeight: 540)
    }

    private func synchronize() {
        Task { await model.synchronize() }
    }
}
