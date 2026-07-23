enum DashboardSection: String, CaseIterable, Identifiable {
    case overview
    case collection
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .overview: "Visão geral"
        case .collection: "Coleção"
        case .settings: "Ajustes"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "rectangle.grid.2x2"
        case .collection: "rectangle.stack.fill"
        case .settings: "gearshape"
        }
    }
}
