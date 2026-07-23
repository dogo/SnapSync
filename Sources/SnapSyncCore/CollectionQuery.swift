import Foundation

public enum CollectionFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case withVariants
    case withBoosters
    case withoutBoosters

    public var id: Self { self }
}

public enum CollectionSort: String, CaseIterable, Identifiable, Sendable {
    case nameAscending
    case nameDescending
    case mostVariants
    case mostBoosters

    public var id: Self { self }
}

public enum CollectionQuery {
    public static func results(
        in cards: [SnapSnapshot.OwnedCard],
        searchText: String,
        filter: CollectionFilter,
        sort: CollectionSort
    ) -> [SnapSnapshot.OwnedCard] {
        let query = searchText.replacing(" ", with: "")
        return cards
            .filter { card in
                (query.isEmpty || card.definitionID.localizedStandardContains(query)) && filter.includes(card)
            }
            .sorted { sort.precedes($0, $1) }
    }
}

private extension CollectionFilter {
    func includes(_ card: SnapSnapshot.OwnedCard) -> Bool {
        switch self {
        case .all: true
        case .withVariants: card.variants.count > 1
        case .withBoosters: (card.boosters ?? 0) > 0
        case .withoutBoosters: (card.boosters ?? 0) == 0
        }
    }
}

private extension CollectionSort {
    func precedes(_ lhs: SnapSnapshot.OwnedCard, _ rhs: SnapSnapshot.OwnedCard) -> Bool {
        switch self {
        case .nameAscending:
            lhs.definitionID.localizedStandardCompare(rhs.definitionID) == .orderedAscending
        case .nameDescending:
            lhs.definitionID.localizedStandardCompare(rhs.definitionID) == .orderedDescending
        case .mostVariants:
            lhs.variants.count == rhs.variants.count
                ? CollectionSort.nameAscending.precedes(lhs, rhs)
                : lhs.variants.count > rhs.variants.count
        case .mostBoosters:
            (lhs.boosters ?? 0) == (rhs.boosters ?? 0)
                ? CollectionSort.nameAscending.precedes(lhs, rhs)
                : (lhs.boosters ?? 0) > (rhs.boosters ?? 0)
        }
    }
}
