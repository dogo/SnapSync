import Foundation

public actor CardCatalog {
    public static let shared = CardCatalog()
    public nonisolated static var defaultCacheURL: URL {
        URL.applicationSupportDirectory.appending(path: "SnapSync/card-catalog.json")
    }

    private let cacheURL: URL
    private let load: @Sendable (URLRequest) async throws -> Data

    public init() {
        cacheURL = Self.defaultCacheURL
        load = { request in
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse,
                  200...299 ~= response.statusCode else {
                throw SnapSyncError.invalidResponse("card catalog request failed")
            }
            return data
        }
    }

    init(
        cacheURL: URL,
        load: @escaping @Sendable (URLRequest) async throws -> Data
    ) {
        self.cacheURL = cacheURL
        self.load = load
    }

    public func entries(now: Date = .now) async throws -> [CardCatalogEntry] {
        let cached = loadCache()
        if let cached, now.timeIntervalSince(cached.fetchedAt) < 86_400 {
            return cached.entries
        }

        do {
            let remote = try JSONDecoder().decode([RemoteCard].self, from: try await load(request(now: now)))
            var entriesByID: [String: CardCatalogEntry] = [:]
            for card in remote where card.collectible == "1" && card.source?.isEmpty == false && card.source != "None" {
                guard let id = card.id, id.isEmpty == false,
                      let name = card.name, name.isEmpty == false else { continue }
                entriesByID[id] = CardCatalogEntry(
                    id: id,
                    name: name,
                    cost: card.cost.flatMap { Int($0) },
                    power: card.power.flatMap { Int($0) },
                    text: card.description.map(Self.markdownText).flatMap { $0.isEmpty ? nil : $0 }
                )
            }
            let entries = entriesByID.values.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            guard entries.isEmpty == false else {
                throw SnapSyncError.invalidResponse("card catalog is empty")
            }
            try save(Cache(fetchedAt: now, entries: entries))
            return entries
        } catch {
            if let cached { return cached.entries }
            throw error
        }
    }

    public nonisolated static func clear(at url: URL = defaultCacheURL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private func request(now: Date) throws -> URLRequest {
        var components = URLComponents(string: "https://api.dotgg.gg/cgfw/getcards")
        components?.queryItems = [
            URLQueryItem(name: "game", value: "marvelsnap"),
            URLQueryItem(name: "mode", value: "plain"),
            URLQueryItem(name: "cache", value: String(Int(now.timeIntervalSince1970 / 86_400))),
        ]
        guard let url = components?.url else {
            throw SnapSyncError.invalidResponse("card catalog URL is invalid")
        }
        return URLRequest(url: url)
    }

    private func loadCache() -> Cache? {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return nil }
        return try? JSONDecoder().decode(Cache.self, from: Data(contentsOf: cacheURL))
    }

    private func save(_ cache: Cache) throws {
        try FileManager.default.createDirectory(
            at: cacheURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(cache).write(to: cacheURL, options: .atomic)
    }

    private struct Cache: Codable {
        let fetchedAt: Date
        let entries: [CardCatalogEntry]
    }

    private static func markdownText(_ html: String) -> String {
        html
            .replacing(/<\/?b>/.ignoresCase(), with: "**")
            .replacing(/<\/?i>/.ignoresCase(), with: "*")
            .replacing(/<[^>]+>/, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct RemoteCard: Decodable {
        let id: String?
        let name: String?
        let collectible: String?
        let source: String?
        let cost: String?
        let power: String?
        let description: String?
    }
}
