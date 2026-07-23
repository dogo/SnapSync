import Foundation

public enum SnapshotHistoryStore {
    public struct Change: Codable, Sendable, Equatable {
        public let observedAt: Date
        public let newCards: Int
        public let newVariants: Int
        public let changedDecks: Int
    }

    public static var defaultURL: URL {
        SyncCheckpoint.defaultURL
            .deletingLastPathComponent()
            .appendingPathComponent("history.json")
    }

    public static func record(
        _ snapshot: SnapSnapshot,
        at url: URL = defaultURL
    ) throws -> Change? {
        guard let entry = try load(from: url),
              entry.snapshot.account?.id == snapshot.account?.id else {
            try save(Entry(snapshot: snapshot, lastChange: nil), to: url)
            return nil
        }

        guard let change = changes(from: entry.snapshot, to: snapshot) else {
            return entry.lastChange
        }

        try save(Entry(snapshot: snapshot, lastChange: change), to: url)
        return change
    }

    public static func lastChange(at url: URL = defaultURL) throws -> Change? {
        try load(from: url)?.lastChange
    }

    public static func clear(at url: URL = defaultURL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private static func changes(from old: SnapSnapshot, to new: SnapSnapshot) -> Change? {
        let oldCards = Dictionary(uniqueKeysWithValues: old.collection.map { ($0.definitionID, $0) })
        let newCards = Dictionary(uniqueKeysWithValues: new.collection.map { ($0.definitionID, $0) })
        let addedCardIDs = Set(newCards.keys).subtracting(oldCards.keys)
        let newVariants = newCards.reduce(into: 0) { count, item in
            guard let previous = oldCards[item.key] else { return }
            count += Set(item.value.variants.map(\.id))
                .subtracting(previous.variants.map(\.id))
                .count
        }

        let oldDecks = Dictionary(uniqueKeysWithValues: old.decks.map { ($0.id, DeckContent($0)) })
        let newDecks = Dictionary(uniqueKeysWithValues: new.decks.map { ($0.id, DeckContent($0)) })
        let changedDecks = Set(oldDecks.keys).union(newDecks.keys).count {
            oldDecks[$0] != newDecks[$0]
        }

        guard addedCardIDs.isEmpty == false || newVariants > 0 || changedDecks > 0 else {
            return nil
        }
        return Change(
            observedAt: new.generatedAt,
            newCards: addedCardIDs.count,
            newVariants: newVariants,
            changedDecks: changedDecks
        )
    }

    private static func load(from url: URL) throws -> Entry? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        try securePrivateFile(at: url)
        do {
            return try JSONDecoder().decode(Entry.self, from: Data(contentsOf: url))
        } catch is DecodingError {
            return nil
        }
    }

    private static func save(_ entry: Entry, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(entry).write(to: url, options: .atomic)
        try securePrivateFile(at: url)
    }

    private struct Entry: Codable {
        let snapshot: SnapSnapshot
        let lastChange: Change?
    }

    private struct DeckContent: Equatable {
        let name: String
        let cards: [String]

        init(_ deck: SnapSnapshot.Deck) {
            name = deck.name
            cards = deck.cardDefinitionIDs
        }
    }
}
