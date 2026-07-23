enum DashboardSection: String, CaseIterable, Identifiable {
    case overview
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .overview: "Visão geral"
        case .settings: "Ajustes"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "rectangle.grid.2x2"
        case .settings: "gearshape"
        }
    }
}
