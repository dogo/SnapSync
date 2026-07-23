import Darwin
import Foundation
import SnapSyncCore

private let usage = """
Usage:
  snapsync discover
  snapsync inspect [--path <nvprod>]
  snapsync export [--path <nvprod>] --output <file>
  snapsync connect [--path <nvprod>]
  snapsync sync [--path <nvprod>] (--dry-run | --confirm)
  snapsync watch [--path <nvprod>] --confirm
  snapsync doctor [--path <nvprod>]
"""

private func parseOptions(_ arguments: ArraySlice<String>, allowed: Set<String>) throws -> [String: String] {
    var options: [String: String] = [:]
    var index = arguments.startIndex

    while index < arguments.endIndex {
        let name = arguments[index]
        guard allowed.contains(name) else {
            throw SnapSyncError.invalidArguments("Unknown option: \(name)")
        }
        let valueIndex = arguments.index(after: index)
        guard valueIndex < arguments.endIndex else {
            throw SnapSyncError.invalidArguments("Missing value for \(name)")
        }
        options[name] = arguments[valueIndex]
        index = arguments.index(after: valueIndex)
    }

    return options
}

private func source(at path: String?) throws -> SnapSource {
    if let path {
        return try SnapSource.inspect(at: URL(fileURLWithPath: path).standardizedFileURL)
    }
    guard let source = SnapSource.discover().first else {
        throw SnapSyncError.sourceNotFound
    }
    return source
}

private func displayPath(_ url: URL) -> String {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    return url.path.hasPrefix(home) ? "~" + url.path.dropFirst(home.count) : url.path
}

private func inspect(_ source: SnapSource) throws {
    let snapshot = try SnapshotIO.read(from: source)
    let variants = snapshot.collection.reduce(0) { $0 + $1.variants.count }

    print("Marvel Snap source inspected")
    print("Path: \(displayPath(source.url))")
    print("Schema: supported")
    print("Account: \(snapshot.account?.displayName ?? "unknown")")
    print("Cards: \(snapshot.collection.count) (\(variants) variants)")
    print("Decks: \(snapshot.decks.count)")
    print("Collection level: \(snapshot.inventory.collectionLevel?.formatted() ?? "unknown")")
    print("Credits: \(snapshot.inventory.credits?.formatted() ?? "unknown")")
    print("Gold: \(snapshot.inventory.gold?.formatted() ?? "unknown")")
    print("Collector's Tokens: \(snapshot.inventory.collectorsTokens?.formatted() ?? "unknown")")
    print("Wild Boosters: \(snapshot.inventory.wildBoosters?.formatted() ?? "unknown")")
    print("Card Boosters: \(snapshot.collection.compactMap(\.boosters).reduce(0, +).formatted())")
}

private func connect(_ source: SnapSource) async throws {
    let snapshot = try SnapshotIO.read(from: source)
    guard let account = snapshot.account,
          let screenName = account.displayName, screenName.isEmpty == false else {
        throw SnapSyncError.unsupportedSchema(file: "ProfileState.json", reason: "account name or ID is missing")
    }

    let connection = try await MarvelSnapProClient().connectAccount(
        screenName: screenName,
        accountID: account.id
    ) { url in
        print("Confirm account link in your browser:")
        print(url.absoluteString)
        print("Waiting for confirmation…")
    }

    try KeychainTokenStore.save(connection.credential.token)
    print("Connected as \(connection.credential.nickname) (\(connection.status))")
}

private func synchronize(
    _ source: SnapSource,
    using synchronizer: SnapSynchronizer = SnapSynchronizer()
) async throws {
    switch try await synchronizer.synchronize(source) {
    case .unchanged:
        print("Nothing changed. Synchronization skipped.")
    case .synchronized(let status):
        print("Synchronization completed (\(status))")
    }
}

private func doctor(path: String?) {
    let discoveredSource: SnapSource?
    if let path {
        discoveredSource = try? SnapSource.inspect(at: URL(fileURLWithPath: path).standardizedFileURL)
    } else {
        discoveredSource = SnapSource.discover().first
    }

    let tokenAvailable: Bool
    do {
        tokenAvailable = try KeychainTokenStore.load() != nil
    } catch {
        tokenAvailable = false
    }

    print(SnapDoctor.report(source: discoveredSource, tokenAvailable: tokenAvailable))
}

private func report(_ error: Error) {
    let message = "error: \((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)\n"
    FileHandle.standardError.write(Data(message.utf8))
}

private func run() async throws {
    let arguments = CommandLine.arguments.dropFirst()
    guard let command = arguments.first else {
        print(usage)
        return
    }

    switch command {
    case "discover":
        guard arguments.count == 1 else {
            throw SnapSyncError.invalidArguments("discover takes no options")
        }
        let sources = SnapSource.discover()
        guard sources.isEmpty == false else {
            throw SnapSyncError.sourceNotFound
        }
        for source in sources {
            print("Marvel Snap source found")
            print("Path: \(displayPath(source.url))")
            print("Files:")
            for name in ["ProfileState.json", "CollectionState.json", "PlayState.json"] {
                print("\(source.files.contains(name) ? "✓" : "–") \(name)")
            }
            print("Confidence: \(source.confidence)")
        }

    case "inspect":
        let options = try parseOptions(arguments.dropFirst(), allowed: ["--path"])
        try inspect(source(at: options["--path"]))

    case "export":
        let options = try parseOptions(arguments.dropFirst(), allowed: ["--path", "--output"])
        guard let output = options["--output"] else {
            throw SnapSyncError.invalidArguments("export requires --output <file>")
        }
        let source = try source(at: options["--path"])
        let snapshot = try SnapshotIO.read(from: source)
        let outputURL = URL(fileURLWithPath: output).standardizedFileURL
        try SnapshotIO.write(snapshot, to: outputURL)
        print("Account: \(snapshot.account?.displayName ?? "unknown")")
        print("Cards: \(snapshot.collection.count)")
        print("Decks: \(snapshot.decks.count)")
        print("Written to \(outputURL.path)")

    case "connect":
        let options = try parseOptions(arguments.dropFirst(), allowed: ["--path"])
        try await connect(source(at: options["--path"]))

    case "sync":
        var syncArguments = Array(arguments.dropFirst())
        let dryRun = syncArguments.firstIndex(of: "--dry-run")
        let confirmed = syncArguments.firstIndex(of: "--confirm")
        guard (dryRun == nil) != (confirmed == nil),
              let modeIndex = dryRun ?? confirmed else {
            throw SnapSyncError.invalidArguments("sync requires exactly one of --dry-run or --confirm")
        }
        syncArguments.remove(at: modeIndex)
        let options = try parseOptions(syncArguments[...], allowed: ["--path"])
        let source = try source(at: options["--path"])

        if dryRun != nil {
            let events = try MarvelSnapProPayload.events(from: source)
            print("DRY RUN — no request sent")
            print("POST \(MarvelSnapProPayload.uploadEndpoint())")
            print("Transport: JSON events, gzip, Base64")
            print("Events:")
            for event in events {
                let count = (try? JSONSerialization.jsonObject(with: Data(event.json.utf8)) as? [Any])?.count ?? 0
                print("- \(event.indicator): \(count) items")
            }
        } else {
            try await synchronize(source)
        }

    case "watch":
        var watchArguments = Array(arguments.dropFirst())
        guard let confirmation = watchArguments.firstIndex(of: "--confirm") else {
            throw SnapSyncError.invalidArguments("watch requires --confirm")
        }
        watchArguments.remove(at: confirmation)
        let options = try parseOptions(watchArguments[...], allowed: ["--path"])
        let source = try source(at: options["--path"])
        let changes = try DirectoryMonitor.changes(at: source.url)
        let synchronizer = SnapSynchronizer()
        try await synchronize(source, using: synchronizer)
        print("Watching \(displayPath(source.url)); press Ctrl-C to stop.")

        let debouncer = ChangeDebouncer()
        for await _ in changes {
            await debouncer.schedule {
                do {
                    try await synchronize(source, using: synchronizer)
                } catch is CancellationError {
                    return
                } catch {
                    report(error)
                }
            }
        }

    case "doctor":
        let options = try parseOptions(arguments.dropFirst(), allowed: ["--path"])
        doctor(path: options["--path"])

    case "help", "--help", "-h":
        print(usage)

    default:
        throw SnapSyncError.invalidArguments("Unknown command: \(command)\n\(usage)")
    }
}

do {
    try await run()
} catch {
    report(error)
    exit(EXIT_FAILURE)
}
