public struct CollectionCard: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let ownedCard: SnapSnapshot.OwnedCard?
    public let cost: Int?
    public let power: Int?
    public let text: String?

    public var isOwned: Bool { ownedCard != nil }
    public var variants: [SnapSnapshot.Variant] { ownedCard?.variants ?? [] }
    public var boosters: Int? { ownedCard?.boosters }

    public init(id: String, name: String, ownedCard: SnapSnapshot.OwnedCard?, cost: Int? = nil, power: Int? = nil, text: String? = nil) {
        self.id = id
        self.name = name
        self.ownedCard = ownedCard
        self.cost = cost
        self.power = power
        self.text = text
    }
}
