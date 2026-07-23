import SnapSyncCore
import SwiftUI

struct CollectionControlsView: View {
    @Binding var filter: CollectionFilter
    @Binding var sort: CollectionSort
    let resultCount: Int

    var body: some View {
        HStack {
            Label("Visualização", systemImage: "line.3.horizontal.decrease.circle.fill")
                .font(.headline)

            Spacer()

            Picker("Filtro", selection: $filter) {
                ForEach(CollectionFilter.allCases) { option in
                    Label(option.title, systemImage: option.systemImage)
                        .tag(option)
                }
            }
            .pickerStyle(.menu)

            Picker("Ordenar", selection: $sort) {
                ForEach(CollectionSort.allCases) { option in
                    Label(option.title, systemImage: option.systemImage)
                        .tag(option)
                }
            }
            .pickerStyle(.menu)

            Text("^[\(resultCount) resultado](inflect: true)")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
    }
}

private extension CollectionFilter {
    var title: String {
        switch self {
        case .all: "Todas"
        case .owned: "Possuídas"
        case .missing: "Faltantes"
        case .withVariants: "Com variantes"
        case .withBoosters: "Com boosters"
        case .withoutBoosters: "Sem boosters"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "rectangle.stack.fill"
        case .owned: "checkmark.circle.fill"
        case .missing: "lock.fill"
        case .withVariants: "sparkles"
        case .withBoosters: "arrow.up.circle.fill"
        case .withoutBoosters: "minus.circle"
        }
    }
}

private extension CollectionSort {
    var title: String {
        switch self {
        case .nameAscending: "Nome A–Z"
        case .nameDescending: "Nome Z–A"
        case .mostVariants: "Mais variantes"
        case .mostBoosters: "Mais boosters"
        }
    }

    var systemImage: String {
        switch self {
        case .nameAscending, .nameDescending: "textformat.abc"
        case .mostVariants: "sparkles"
        case .mostBoosters: "arrow.up.circle.fill"
        }
    }
}
