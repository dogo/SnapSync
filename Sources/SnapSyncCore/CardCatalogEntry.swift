public struct CardCatalogEntry: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let cost: Int?
    public let power: Int?
    public let text: String?

    public init(id: String, name: String, cost: Int? = nil, power: Int? = nil, text: String? = nil) {
        self.id = id
        self.name = name
        self.cost = cost
        self.power = power
        self.text = text
    }
}
