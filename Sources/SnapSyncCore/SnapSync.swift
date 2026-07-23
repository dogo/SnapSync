import CryptoKit
import Darwin
import Dispatch
import Foundation
import OSLog
import Security
import zlib

func securePrivateFile(at url: URL) throws {
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
}

private extension Logger {
    static let discovery = Logger(subsystem: "com.snapsync", category: "discovery")
    static let parsing = Logger(subsystem: "com.snapsync", category: "parsing")
    static let sync = Logger(subsystem: "com.snapsync", category: "sync")
}

public enum SnapSyncError: LocalizedError {
    case invalidArguments(String)
    case sourceNotFound
    case missingFile(String)
    case unsupportedSchema(file: String, reason: String)
    case invalidResponse(String)
    case httpStatus(Int)
    case keychain(Int32)
    case compression(Int32)
    case linkTimedOut
    case fileChangedDuringRead(String)

    public var errorDescription: String? {
        switch self {
        case .invalidArguments(let message): message
        case .sourceNotFound: "Marvel Snap source not found; pass --path to the nvprod directory"
        case .missingFile(let name): "Missing required file: \(name)"
        case .unsupportedSchema(let file, let reason): "Unsupported \(file) schema: \(reason)"
        case .invalidResponse(let reason): "Invalid MarvelSnap.pro response: \(reason)"
        case .httpStatus(let status): "MarvelSnap.pro returned HTTP \(status)"
        case .keychain(let status): "Keychain operation failed with status \(status)"
        case .compression(let status): "gzip compression failed with status \(status)"
        case .linkTimedOut: "MarvelSnap.pro account confirmation timed out"
        case .fileChangedDuringRead(let name): "File changed repeatedly while reading: \(name)"
        }
    }
}

public struct SnapSource: Sendable, Equatable {
    public let url: URL
    public let files: [String]

    public var confidence: String {
        files.contains("CollectionState.json") && files.contains("ProfileState.json") ? "high" : "medium"
    }

    public static func inspect(at url: URL, fileManager: FileManager = .default) throws -> Self {
        let files = try fileManager.contentsOfDirectory(atPath: url.path).sorted()
        guard files.contains("CollectionState.json") else {
            throw SnapSyncError.missingFile("CollectionState.json")
        }
        Logger.discovery.debug("Source inspected with \(files.count, privacy: .public) files")
        return Self(url: url.standardizedFileURL, files: files)
    }

    public static func discover(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default
    ) -> [Self] {
        let containers = home.appendingPathComponent("Library/Containers", isDirectory: true)
        let children = (try? fileManager.contentsOfDirectory(
            at: containers,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        let sources = children.compactMap { container in
            let candidate = container.appendingPathComponent(
                "Data/Documents/Standalone/States/nvprod",
                isDirectory: true
            )
            return try? inspect(at: candidate, fileManager: fileManager)
        }
        .sorted {
            $0.files.contains("ProfileState.json") && $1.files.contains("ProfileState.json") == false
        }
        Logger.discovery.info("Discovery completed with \(sources.count, privacy: .public) sources")
        return sources
    }
}

public enum StableFileReader {
    public static func read(from url: URL, attempts: Int = 3) throws -> Data {
        try read(from: url, attempts: attempts, retryDelay: 0.15) { _ in }
    }

    static func read(
        from url: URL,
        attempts: Int,
        retryDelay: TimeInterval,
        afterRead: (Int) throws -> Void
    ) throws -> Data {
        guard attempts > 0 else {
            throw SnapSyncError.invalidArguments("stable file read requires at least one attempt")
        }

        for attempt in 0..<attempts {
            let before = try FileState(url)
            let data = try Data(contentsOf: url)
            try afterRead(attempt)
            let after = try FileState(url)
            if before == after { return data }
            if attempt < attempts - 1, retryDelay > 0 {
                Thread.sleep(forTimeInterval: retryDelay)
            }
        }

        throw SnapSyncError.fileChangedDuringRead(url.lastPathComponent)
    }

    private struct FileState: Equatable {
        let size: Int?
        let modifiedAt: Date?
        let fileNumber: UInt64?

        init(_ url: URL) throws {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            size = (attributes[.size] as? NSNumber)?.intValue
            modifiedAt = attributes[.modificationDate] as? Date
            fileNumber = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value
        }
    }
}

public enum FolderBookmarkStore {
    public static var defaultURL: URL {
        SyncCheckpoint.defaultURL
            .deletingLastPathComponent()
            .appendingPathComponent("folder.bookmark")
    }

    public static func saveAccess(to url: URL, at bookmarkURL: URL = defaultURL) throws {
        let data = try url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        try FileManager.default.createDirectory(
            at: bookmarkURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: bookmarkURL, options: .atomic)
        try securePrivateFile(at: bookmarkURL)
    }

    public static func restoreURL(from bookmarkURL: URL = defaultURL) throws -> URL? {
        guard FileManager.default.fileExists(atPath: bookmarkURL.path) else { return nil }
        try securePrivateFile(at: bookmarkURL)
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: Data(contentsOf: bookmarkURL),
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        if isStale {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            try saveAccess(to: url, at: bookmarkURL)
        }
        return url
    }

    public static func clear(at bookmarkURL: URL = defaultURL) throws {
        guard FileManager.default.fileExists(atPath: bookmarkURL.path) else { return }
        try FileManager.default.removeItem(at: bookmarkURL)
    }
}

public enum DirectoryMonitor {
    public static func changes(at url: URL) throws -> AsyncStream<Void> {
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }

        let (stream, continuation) = AsyncStream.makeStream(
            of: Void.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: .write,
            queue: DispatchQueue(label: "com.snapsync.directory-monitor")
        )
        source.setEventHandler { continuation.yield() }
        source.setCancelHandler {
            close(descriptor)
            continuation.finish()
        }
        continuation.onTermination = { _ in source.cancel() }
        source.resume()
        return stream
    }
}

public actor ChangeDebouncer {
    private var generation = 0
    private var timer: Task<Void, Never>?
    private var running = false
    private var queuedAction: (@Sendable () async -> Void)?

    public init() {}

    @discardableResult
    public func schedule(
        after delay: Duration = .milliseconds(600),
        action: @escaping @Sendable () async -> Void
    ) -> Task<Void, Never> {
        generation += 1
        let scheduledGeneration = generation
        timer?.cancel()
        if running { queuedAction = nil }

        let next = Task { [weak self] in
            do {
                try await Task.sleep(for: delay)
                await self?.fire(scheduledGeneration, action: action)
            } catch is CancellationError {
                return
            } catch {
                return
            }
        }
        timer = next
        return next
    }

    private func fire(_ scheduledGeneration: Int, action: @escaping @Sendable () async -> Void) async {
        guard scheduledGeneration == generation else { return }
        timer = nil
        guard running == false else {
            queuedAction = action
            return
        }

        running = true
        var next: (@Sendable () async -> Void)? = action
        while let current = next {
            queuedAction = nil
            await current()
            next = queuedAction
        }
        running = false
    }

    deinit {
        timer?.cancel()
    }
}

public struct SnapSnapshot: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let generatedAt: Date
    public let applicationVersion: String?
    public let account: Account?
    public let collection: [OwnedCard]
    public let decks: [Deck]
    public let inventory: Inventory

    public struct Account: Codable, Sendable, Equatable {
        public let id: String
        public let displayName: String?
    }

    public struct OwnedCard: Codable, Sendable, Equatable, Identifiable {
        public let definitionID: String
        public let variants: [Variant]
        public let boosters: Int?

        public var id: String { definitionID }
    }

    public struct Variant: Codable, Sendable, Equatable {
        public let id: String
        public let variantID: String?
        public let rarityID: String?
        public let borderID: String?
    }

    public struct Deck: Codable, Sendable, Equatable, Identifiable {
        public let id: String
        public let name: String
        public let cardDefinitionIDs: [String]
        public let lastModifiedAt: String?
    }

    public struct Inventory: Codable, Sendable, Equatable {
        public let collectionLevel: Int?
        public let credits: Int?
        public let gold: Int?
        public let collectorsTokens: Int?
        public let wildBoosters: Int?
    }
}

public enum SnapSchema: Int, Codable, Sendable {
    case v1 = 1

    public var fingerprint: String {
        "CollectionState.ServerState.{Cards,Decks}"
    }

    public static func detect(collectionData: Data) throws -> Self {
        do {
            guard let object = try JSONSerialization.jsonObject(with: collectionData) as? [String: Any] else {
                throw SnapSyncError.unsupportedSchema(
                    file: "CollectionState.json",
                    reason: "root is not an object"
                )
            }
            return try detect(collectionObject: object)
        } catch let error as SnapSyncError {
            throw error
        } catch {
            throw SnapSyncError.unsupportedSchema(file: "CollectionState.json", reason: "invalid JSON")
        }
    }

    static func detect(collectionObject: [String: Any]) throws -> Self {
        guard let state = collectionObject["ServerState"] as? [String: Any],
              state["Cards"] is [Any],
              state["Decks"] is [Any] else {
            throw SnapSyncError.unsupportedSchema(
                file: "CollectionState.json",
                reason: "fingerprint does not match V1 (requires ServerState.Cards and ServerState.Decks arrays)"
            )
        }
        return .v1
    }
}

public struct MarvelSnapProEvent: Codable, Sendable, Equatable {
    public let time: Int
    public let indicator: String
    public let json: String
    public let uid: String
}

public struct SyncCheckpoint: Codable, Sendable, Equatable {
    public let snapshotHash: String
    public let syncedAt: Date
    public let accountID: String

    public static var defaultURL: URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
        return applicationSupport.appendingPathComponent("SnapSync/checkpoint.json")
    }

    public static func matches(_ events: [MarvelSnapProEvent], at url: URL = defaultURL) throws -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        try securePrivateFile(at: url)
        let checkpoint = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        return checkpoint.snapshotHash == (try hash(of: events))
    }

    public static func save(
        _ events: [MarvelSnapProEvent],
        to url: URL = defaultURL,
        now: Date = .now
    ) throws {
        guard let accountID = events.first?.uid else {
            throw SnapSyncError.invalidArguments("cannot checkpoint an empty upload")
        }
        let checkpoint = Self(snapshotHash: try hash(of: events), syncedAt: now, accountID: accountID)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(checkpoint).write(to: url, options: .atomic)
        try securePrivateFile(at: url)
    }

    public static func clear(at url: URL = defaultURL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private static func hash(of events: [MarvelSnapProEvent]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return SHA256.hash(data: try encoder.encode(events))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

public enum SyncOutbox {
    public static var defaultURL: URL {
        SyncCheckpoint.defaultURL
            .deletingLastPathComponent()
            .appendingPathComponent("outbox/latest.json")
    }

    public static func load(from url: URL = defaultURL) throws -> [MarvelSnapProEvent]? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        try securePrivateFile(at: url)
        do {
            return try JSONDecoder().decode(Entry.self, from: Data(contentsOf: url)).events
        } catch is DecodingError {
            return nil
        }
    }

    public static func save(
        _ events: [MarvelSnapProEvent],
        to url: URL = defaultURL,
        now: Date = .now
    ) throws {
        guard events.isEmpty == false else {
            throw SnapSyncError.invalidArguments("cannot enqueue an empty upload")
        }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        try encoder.encode(Entry(savedAt: now, events: events)).write(to: url, options: .atomic)
        try securePrivateFile(at: url)
    }

    public static func remove(at url: URL = defaultURL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private struct Entry: Codable {
        let savedAt: Date
        let events: [MarvelSnapProEvent]
    }
}

public enum MarvelSnapProPayload {
    public static func uploadEndpoint(version: String = "0.4.0") -> String {
        "https://marvelsnap.pro/snap/donew2.php?cmd=cm_uploadpackfile&version=\(version)m"
    }

    public static func events(from source: SnapSource) throws -> [MarvelSnapProEvent] {
        let collection = try jsonObject("CollectionState.json", from: source.url)
        _ = try SnapSchema.detect(collectionObject: collection)
        guard let state = collection["ServerState"] as? [String: Any],
              let decks = state["Decks"] as? [Any],
              let cards = state["Cards"] as? [Any] else {
            throw SnapSyncError.unsupportedSchema(
                file: "CollectionState.json",
                reason: "ServerState.Cards or ServerState.Decks is missing"
            )
        }

        let profile = try jsonObject("ProfileState.json", from: source.url)
        let profileAccount = (profile["ServerState"] as? [String: Any])?["Account"] as? [String: Any]
        guard let accountID = profileAccount?["Id"] as? String ?? profile["AccountId"] as? String else {
            throw SnapSyncError.unsupportedSchema(file: "ProfileState.json", reason: "account ID is missing")
        }

        return [
            MarvelSnapProEvent(time: 0, indicator: "Decks", json: try jsonString(decks), uid: accountID),
            MarvelSnapProEvent(time: 0, indicator: "Collection", json: try jsonString(cards), uid: accountID),
        ]
    }

    private static func jsonObject(_ name: String, from directory: URL) throws -> [String: Any] {
        let url = directory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SnapSyncError.missingFile(name)
        }

        do {
            guard let object = try JSONSerialization.jsonObject(with: StableFileReader.read(from: url)) as? [String: Any] else {
                throw SnapSyncError.unsupportedSchema(file: name, reason: "root is not an object")
            }
            return object
        } catch let error as SnapSyncError {
            throw error
        } catch {
            throw SnapSyncError.unsupportedSchema(file: name, reason: error.localizedDescription)
        }
    }

    private static func jsonString(_ object: Any) throws -> String {
        String(decoding: try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]), as: UTF8.self)
    }
}

public struct MarvelSnapProCredential: Sendable, Equatable {
    public let userID: String
    public let token: String
    public let nickname: String
}

public enum MarvelSnapProLink: Sendable, Equatable {
    case confirmationRequired(url: URL, requestID: String)
    case linked(MarvelSnapProCredential)
}

public struct MarvelSnapProClient: Sendable {
    private let load: @Sendable (URLRequest) async throws -> (Data, URLResponse)
    private let retryDelays: [Duration]
    private let sleep: @Sendable (Duration) async throws -> Void
    private let now: @Sendable () -> Date

    private static let defaultRetryDelays: [Duration] = [
        .seconds(5), .seconds(15), .seconds(60), .seconds(300), .seconds(900),
    ]

    public init(session: URLSession = .shared) {
        load = { try await session.data(for: $0) }
        retryDelays = Self.defaultRetryDelays
        sleep = { try await Task.sleep(for: $0) }
        now = { .now }
    }

    init(
        load: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse),
        retryDelays: [Duration] = defaultRetryDelays,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.load = load
        self.retryDelays = retryDelays
        self.sleep = sleep
        self.now = now
    }

    public func startLink(screenName: String, accountID: String) async throws -> MarvelSnapProLink {
        let response = try await post(
            command: "cm_tokenrequest",
            body: ["playerid": screenName, "plguid": accountID]
        )

        switch response["mode"] {
        case "needauth":
            guard let requestID = response["request"],
                  var components = URLComponents(string: "https://marvelsnap.pro/sync/") else {
                throw SnapSyncError.invalidResponse("missing confirmation request")
            }
            components.queryItems = [URLQueryItem(name: "request", value: requestID)]
            guard let url = components.url else {
                throw SnapSyncError.invalidResponse("invalid confirmation URL")
            }
            return .confirmationRequired(url: url, requestID: requestID)

        case "hasauth":
            return .linked(try credential(from: response))

        default:
            throw SnapSyncError.invalidResponse("unknown token request mode")
        }
    }

    public func checkLink(requestID: String) async throws -> MarvelSnapProCredential? {
        let response = try await post(command: "cm_tokencheck", body: ["request": requestID])
        guard response["token"]?.isEmpty == false else { return nil }
        return try credential(from: response)
    }

    public func connectAccount(
        screenName: String,
        accountID: String,
        timeZone: TimeZone = .current,
        onConfirmationRequired: @Sendable (URL) async throws -> Void
    ) async throws -> (credential: MarvelSnapProCredential, status: String) {
        Logger.sync.info("Account linking started")
        let credential: MarvelSnapProCredential
        switch try await startLink(screenName: screenName, accountID: accountID) {
        case .linked(let existing):
            credential = existing

        case .confirmationRequired(let url, let requestID):
            Logger.sync.notice("Account confirmation required")
            try await onConfirmationRequired(url)

            var confirmed: MarvelSnapProCredential?
            for attempt in 0...120 {
                try Task.checkCancellation()
                if let result = try await checkLink(requestID: requestID) {
                    confirmed = result
                    break
                }
                if attempt < 120 { try await sleep(.seconds(5)) }
            }
            guard let confirmed else { throw SnapSyncError.linkTimedOut }
            credential = confirmed
        }

        let status = try await associate(
            credential,
            screenName: screenName,
            accountID: accountID,
            timeZone: timeZone
        )
        Logger.sync.info("Account linking completed")
        return (credential, status)
    }

    @discardableResult
    public func associate(
        _ credential: MarvelSnapProCredential,
        screenName: String,
        accountID: String,
        timeZone: TimeZone = .current
    ) async throws -> String {
        let response = try await post(
            command: "cm_setuserdata",
            body: [
                "snapId": accountID,
                "snapNick": screenName,
                "token": credential.token,
                "usertime": userTime(in: timeZone),
            ]
        )
        guard let status = response["status"] else {
            throw SnapSyncError.invalidResponse("missing association status")
        }
        return status
    }

    public func validate(token: String, timeZone: TimeZone = .current) async throws -> String {
        let response = try await post(
            command: "cm_userbytokenid",
            body: ["cm_userbytokenid": token, "usertime": userTime(in: timeZone)]
        )
        guard let status = response["status"], status != "UNSET_USER" else {
            throw SnapSyncError.invalidResponse("stored token is not linked")
        }
        return status
    }

    public func upload(_ events: [MarvelSnapProEvent]) async throws -> String {
        guard let url = URL(string: MarvelSnapProPayload.uploadEndpoint()) else {
            throw SnapSyncError.invalidResponse("invalid upload endpoint")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = Data(try gzip(JSONEncoder().encode(events)).base64EncodedString().utf8)

        let response = try await perform(request)
        guard let status = response["status"] else {
            throw SnapSyncError.invalidResponse("missing upload status")
        }
        return status
    }

    private func post(command: String, body: [String: String]) async throws -> [String: String] {
        guard let url = URL(string: "https://marvelsnap.pro/snap/donew2.php?cmd=\(command)&version=0.4.0m") else {
            throw SnapSyncError.invalidResponse("invalid endpoint")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        return try await perform(request)
    }

    private func perform(_ request: URLRequest) async throws -> [String: String] {
        for attempt in 0...retryDelays.count {
            try Task.checkCancellation()
            let result: (Data, URLResponse)
            do {
                result = try await load(request)
            } catch {
                guard attempt < retryDelays.count, isRecoverable(error) else { throw error }
                try await sleep(retryDelays[attempt])
                continue
            }

            let (data, urlResponse) = result
            guard let response = urlResponse as? HTTPURLResponse else {
                throw SnapSyncError.invalidResponse("missing HTTP response")
            }
            if attempt < retryDelays.count, isRecoverable(response.statusCode) {
                try await sleep(retryDelay(from: response, fallback: retryDelays[attempt]))
                continue
            }
            guard (200..<300).contains(response.statusCode) else {
                throw SnapSyncError.httpStatus(response.statusCode)
            }
            do {
                return try JSONDecoder().decode([String: String].self, from: data)
            } catch {
                throw SnapSyncError.invalidResponse("response is not a string dictionary")
            }
        }
        throw SnapSyncError.invalidResponse("retry loop ended unexpectedly")
    }

    private func isRecoverable(_ error: Error) -> Bool {
        guard let code = (error as? URLError)?.code else { return false }
        switch code {
        case .timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost,
             .dnsLookupFailed, .notConnectedToInternet, .resourceUnavailable:
            return true
        default:
            return false
        }
    }

    private func isRecoverable(_ status: Int) -> Bool {
        status == 408 || status == 429 || (500...504).contains(status)
    }

    private func retryDelay(from response: HTTPURLResponse, fallback: Duration) -> Duration {
        guard let value = response.value(forHTTPHeaderField: "Retry-After") else { return fallback }
        if let seconds = Int64(value), seconds >= 0 {
            return .seconds(min(seconds, 900))
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for format in [
            "EEE',' dd MMM yyyy HH':'mm':'ss zzz",
            "EEEE',' dd-MMM-yy HH':'mm':'ss zzz",
            "EEE MMM d HH':'mm':'ss yyyy",
        ] {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                let milliseconds = Int64(min(max(date.timeIntervalSince(now()), 0), 900) * 1_000)
                return .milliseconds(milliseconds)
            }
        }
        return fallback
    }

    private func userTime(in timeZone: TimeZone) -> String {
        let seconds = timeZone.secondsFromGMT()
        return seconds.isMultiple(of: 3600)
            ? String(seconds / 3600)
            : String(Double(seconds) / 3600)
    }

    private func credential(from response: [String: String]) throws -> MarvelSnapProCredential {
        guard let userID = response["uid"],
              let token = response["token"], token.isEmpty == false,
              let nickname = response["nick"] else {
            throw SnapSyncError.invalidResponse("missing linked account credentials")
        }
        return MarvelSnapProCredential(userID: userID, token: token, nickname: nickname)
    }
}

public enum SyncOutcome: Sendable, Equatable {
    case unchanged
    case synchronized(String)
}

public struct SnapSynchronizer: Sendable {
    private let client: MarvelSnapProClient
    private let loadToken: @Sendable () throws -> String?
    private let checkpointURL: URL
    private let outboxURL: URL

    public init() {
        client = MarvelSnapProClient()
        loadToken = { try KeychainTokenStore.load() }
        checkpointURL = SyncCheckpoint.defaultURL
        outboxURL = SyncOutbox.defaultURL
    }

    init(
        client: MarvelSnapProClient,
        loadToken: @escaping @Sendable () throws -> String?,
        checkpointURL: URL,
        outboxURL: URL
    ) {
        self.client = client
        self.loadToken = loadToken
        self.checkpointURL = checkpointURL
        self.outboxURL = outboxURL
    }

    public func synchronize(_ source: SnapSource) async throws -> SyncOutcome {
        Logger.sync.info("Synchronization started")
        let currentEvents = try MarvelSnapProPayload.events(from: source)
        if try SyncCheckpoint.matches(currentEvents, at: checkpointURL) {
            try SyncOutbox.remove(at: outboxURL)
            Logger.sync.info("Synchronization skipped because the snapshot is unchanged")
            return .unchanged
        }

        let events: [MarvelSnapProEvent]
        if let pending = try SyncOutbox.load(from: outboxURL), pending == currentEvents {
            events = pending
            Logger.sync.debug("Pending snapshot reused from outbox")
        } else {
            try SyncOutbox.save(currentEvents, to: outboxURL)
            events = currentEvents
            Logger.sync.debug("Current snapshot saved to outbox")
        }
        guard let token = try loadToken() else {
            throw SnapSyncError.invalidArguments("no linked account; run snapsync connect first")
        }

        _ = try await client.validate(token: token)
        let status = try await client.upload(events)
        try SyncCheckpoint.save(events, to: checkpointURL)
        try SyncOutbox.remove(at: outboxURL)
        Logger.sync.info("Synchronization completed")
        return .synchronized(status)
    }
}

private func gzip(_ input: Data) throws -> Data {
    var stream = z_stream()
    let initialized = deflateInit2_(
        &stream,
        Z_DEFAULT_COMPRESSION,
        Z_DEFLATED,
        MAX_WBITS + 16,
        8,
        Z_DEFAULT_STRATEGY,
        ZLIB_VERSION,
        Int32(MemoryLayout<z_stream>.size)
    )
    guard initialized == Z_OK else { throw SnapSyncError.compression(initialized) }
    defer { deflateEnd(&stream) }

    return try input.withUnsafeBytes { inputBytes in
        stream.next_in = UnsafeMutablePointer(mutating: inputBytes.bindMemory(to: Bytef.self).baseAddress)
        stream.avail_in = uInt(input.count)
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 32_768)
        let bufferSize = buffer.count
        var status: Int32

        repeat {
            status = buffer.withUnsafeMutableBytes { outputBytes in
                stream.next_out = outputBytes.bindMemory(to: Bytef.self).baseAddress
                stream.avail_out = uInt(bufferSize)
                return deflate(&stream, Z_FINISH)
            }
            guard status == Z_OK || status == Z_STREAM_END else {
                throw SnapSyncError.compression(status)
            }
            result.append(contentsOf: buffer.prefix(bufferSize - Int(stream.avail_out)))
        } while status != Z_STREAM_END

        return result
    }
}

public enum KeychainTokenStore {
    private static let service = "com.snapsync.marvelsnappro"
    private static let account = "token"

    public static func load() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            throw SnapSyncError.keychain(status)
        }
        return token
    }

    public static func save(_ token: String) throws {
        let data = Data(token.utf8)
        let update = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var item = baseQuery
            item[kSecValueData as String] = data
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw SnapSyncError.keychain(addStatus) }
        } else if status != errSecSuccess {
            throw SnapSyncError.keychain(status)
        }
    }

    public static func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SnapSyncError.keychain(status)
        }
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

public enum SnapDoctor {
    public static func report(
        source: SnapSource?,
        tokenAvailable: Bool,
        checkpointURL: URL = SyncCheckpoint.defaultURL,
        outboxURL: URL = SyncOutbox.defaultURL
    ) -> String {
        let readable = source.map { FileManager.default.isReadableFile(atPath: $0.url.path) } ?? false
        let snapshot = source.flatMap { try? SnapshotIO.read(from: $0) }
        let requiredFiles = ["ProfileState.json", "CollectionState.json"]
        let filesReady = source.map { candidate in
            requiredFiles.allSatisfy(candidate.files.contains)
        } ?? false
        let ready = readable && filesReady && snapshot?.account != nil && tokenAvailable
        let variants = snapshot?.collection.reduce(0) { $0 + $1.variants.count } ?? 0
        let hasCheckpoint = FileManager.default.fileExists(atPath: checkpointURL.path)
        let hasPendingOutbox = (try? SyncOutbox.load(from: outboxURL)) != nil
        let version = ProcessInfo.processInfo.operatingSystemVersion

        var lines = [
            "SnapSync Doctor",
            "",
            "System",
            "✓ macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)",
            "✓ \(architecture)",
            "",
            "Source",
            "\(source == nil ? "✗" : "✓") Marvel Snap directory found",
            "\(readable ? "✓" : "✗") Directory readable",
            "✓ Path hidden",
            "",
            "Files",
        ]
        for name in requiredFiles {
            lines.append("\(source?.files.contains(name) == true ? "✓" : "✗") \(name)")
        }
        lines += [
            "\(source?.files.contains("PlayState.json") == true ? "✓" : "–") PlayState.json (optional)",
            "",
            "Parsing",
            "\(snapshot == nil ? "✗" : "✓") Schema V\(snapshot?.schemaVersion ?? 0) recognized",
            "\(snapshot?.account == nil ? "✗" : "✓") Account recognized",
            "\(snapshot == nil ? "✗" : "✓") \(snapshot?.collection.count ?? 0) cards · \(variants) variants",
            "\(snapshot == nil ? "✗" : "✓") \(snapshot?.decks.count ?? 0) decks",
            "",
            "MarvelSnap.pro",
            "\(tokenAvailable ? "✓" : "✗") Token available",
            "",
            "Sync",
            "\(hasCheckpoint ? "✓" : "–") Previous synchronization recorded",
            "\(hasPendingOutbox ? "– Pending outbox item" : "✓ No pending outbox items")",
            "",
            "Overall: \(ready ? "READY" : "NEEDS ATTENTION")",
        ]
        return lines.joined(separator: "\n")
    }

    private static var architecture: String {
        #if arch(arm64)
        "arm64"
        #elseif arch(x86_64)
        "x86_64"
        #else
        "unknown architecture"
        #endif
    }
}

public enum SnapshotIO {
    public static func read(from source: SnapSource, now: Date = .now) throws -> SnapSnapshot {
        let collectionData = try read("CollectionState.json", from: source.url)
        let schema = try SnapSchema.detect(collectionData: collectionData)
        let collection: CollectionFile = try decode(collectionData, file: "CollectionState.json")
        guard let state = collection.serverState,
              let rawCards = state.cards,
              let rawDecks = state.decks else {
            throw SnapSyncError.unsupportedSchema(
                file: "CollectionState.json",
                reason: "ServerState.Cards or ServerState.Decks is missing"
            )
        }

        let profileURL = source.url.appendingPathComponent("ProfileState.json")
        let profile: ProfileFile? = source.files.contains("ProfileState.json")
            ? try decode(profileURL.lastPathComponent, from: source.url)
            : nil

        let collectionCards = Dictionary(grouping: rawCards, by: \RawCard.definitionID)
            .map { definitionID, cards in
                SnapSnapshot.OwnedCard(
                    definitionID: definitionID,
                    variants: cards.map {
                        SnapSnapshot.Variant(
                            id: $0.id,
                            variantID: $0.variantID,
                            rarityID: $0.rarityID,
                            borderID: $0.borderID
                        )
                    }
                    .sorted { $0.id < $1.id },
                    boosters: state.cardDefStats?.stats?.boostersByCardID[definitionID]
                )
            }
            .sorted { $0.definitionID < $1.definitionID }

        let decks = rawDecks.filter { $0.deckSlotDefinitionID == nil }.map {
            SnapSnapshot.Deck(
                id: $0.id,
                name: $0.name,
                cardDefinitionIDs: ($0.cards ?? []).map(\.definitionID),
                lastModifiedAt: $0.lastModifiedAt
            )
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        let accountID = profile?.serverState?.account?.id ?? profile?.accountID ?? collection.accountID
        let account = accountID.map {
            SnapSnapshot.Account(id: $0, displayName: profile?.serverState?.account?.name)
        }

        let snapshot = SnapSnapshot(
            schemaVersion: schema.rawValue,
            generatedAt: now,
            applicationVersion: collection.applicationVersion,
            account: account,
            collection: collectionCards,
            decks: decks,
            inventory: SnapSnapshot.Inventory(
                collectionLevel: state.collectionScore?.amount,
                credits: profile?.serverState?.wallet?.currencies?.credits?.totalAmount,
                gold: profile?.serverState?.wallet?.currencies?.gold?.totalAmount,
                collectorsTokens: profile?.serverState?.wallet?.currencies?.collectorsTokens?.totalAmount,
                wildBoosters: profile?.serverState?.wallet?.currencies?.wildBoosters?.totalAmount
            )
        )
        let variants = collectionCards.reduce(0) { $0 + $1.variants.count }
        Logger.parsing.info(
            "Schema V\(schema.rawValue, privacy: .public) parsed with \(collectionCards.count, privacy: .public) cards, \(variants, privacy: .public) variants, and \(decks.count, privacy: .public) decks"
        )
        return snapshot
    }

    public static func write(_ snapshot: SnapSnapshot, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(snapshot).write(to: url, options: .atomic)
    }

    private static func decode<T: Decodable>(_ name: String, from directory: URL) throws -> T {
        try decode(read(name, from: directory), file: name)
    }

    private static func read(_ name: String, from directory: URL) throws -> Data {
        let url = directory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SnapSyncError.missingFile(name)
        }
        return try StableFileReader.read(from: url)
    }

    private static func decode<T: Decodable>(_ data: Data, file name: String) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as SnapSyncError {
            throw error
        } catch {
            throw SnapSyncError.unsupportedSchema(file: name, reason: error.localizedDescription)
        }
    }
}

private struct ProfileFile: Decodable {
    let accountID: String?
    let serverState: ServerState?

    struct ServerState: Decodable {
        let account: Account?
        let wallet: Wallet?

        enum CodingKeys: String, CodingKey {
            case account = "Account"
            case wallet = "Wallet"
        }
    }

    struct Account: Decodable {
        let id: String?
        let name: String?

        enum CodingKeys: String, CodingKey {
            case id = "Id"
            case name = "Name"
        }
    }

    enum CodingKeys: String, CodingKey {
        case accountID = "AccountId"
        case serverState = "ServerState"
    }
}

private struct CollectionFile: Decodable {
    let accountID: String?
    let applicationVersion: String?
    let serverState: ServerState?

    struct ServerState: Decodable {
        let cards: [RawCard]?
        let decks: [RawDeck]?
        let cardDefStats: RawCardDefStats?
        let collectionScore: RawCollectionScore?

        enum CodingKeys: String, CodingKey {
            case cards = "Cards"
            case decks = "Decks"
            case cardDefStats = "CardDefStats"
            case collectionScore = "CollectionScore"
        }
    }

    enum CodingKeys: String, CodingKey {
        case accountID = "AccountId"
        case applicationVersion = "ApplicationVersion"
        case serverState = "ServerState"
    }
}

private struct Wallet: Decodable {
    let currencies: Currencies?

    struct Currencies: Decodable {
        let credits: RawCurrency?
        let gold: RawCurrency?
        let collectorsTokens: RawCurrency?
        let wildBoosters: RawCurrency?

        enum CodingKeys: String, CodingKey {
            case credits = "Credits"
            case gold = "Gold"
            case collectorsTokens = "CollectorsTokens"
            case wildBoosters = "WildBooster"
        }
    }

    enum CodingKeys: String, CodingKey { case currencies = "_currencies" }
}

private struct RawCurrency: Decodable {
    let totalAmount: Int?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        totalAmount = container.allKeys.lazy.compactMap {
            try? container.decode(Balance.self, forKey: $0).totalAmount
        }.first
    }

    private struct Balance: Decodable {
        let totalAmount: Int?

        enum CodingKeys: String, CodingKey { case totalAmount = "TotalAmount" }
    }
}

private struct RawCardDefStats: Decodable {
    let stats: RawCardStats?

    enum CodingKeys: String, CodingKey { case stats = "Stats" }
}

private struct RawCardStats: Decodable {
    let boostersByCardID: [String: Int]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        boostersByCardID = Dictionary(uniqueKeysWithValues: container.allKeys.compactMap { key in
            guard let stat = try? container.decode(Stat.self, forKey: key),
                  let boosters = stat.boosters else { return nil }
            return (key.stringValue, boosters)
        })
    }

    private struct Stat: Decodable {
        let boosters: Int?

        enum CodingKeys: String, CodingKey { case boosters = "Boosters" }
    }
}

private struct RawCollectionScore: Decodable {
    let amount: Int?

    enum CodingKeys: String, CodingKey { case amount = "Amount" }
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

private struct RawCard: Decodable {
    let id: String
    let definitionID: String
    let variantID: String?
    let rarityID: String?
    let borderID: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case definitionID = "CardDefId"
        case variantID = "ArtVariantDefId"
        case rarityID = "RarityDefId"
        case borderID = "BorderDefId"
    }
}

private struct RawDeck: Decodable {
    let id: String
    let name: String
    let cards: [RawDeckCard]?
    let lastModifiedAt: String?
    let deckSlotDefinitionID: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case cards = "Cards"
        case lastModifiedAt = "TimeUpdated"
        case deckSlotDefinitionID = "DeckSlotDefId"
    }
}

private struct RawDeckCard: Decodable {
    let definitionID: String

    enum CodingKeys: String, CodingKey { case definitionID = "CardDefId" }
}
