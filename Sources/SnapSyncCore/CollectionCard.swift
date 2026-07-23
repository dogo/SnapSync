public struct CollectionCard: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let ownedCard: SnapSnapshot.OwnedCard?

    public var isOwned: Bool { ownedCard != nil }
    public var variants: [SnapSnapshot.Variant] { ownedCard?.variants ?? [] }
    public var boosters: Int? { ownedCard?.boosters }

    public init(id: String, name: String, ownedCard: SnapSnapshot.OwnedCard?) {
        self.id = id
        self.name = name
        self.ownedCard = ownedCard
    }
}
