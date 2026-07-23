import AppKit
import Combine
import Foundation
import OSLog
import SnapSyncCore

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var statusText = "Procurando Marvel Snap…"
    @Published private(set) var accountName = "—"
    @Published private(set) var collection: [SnapSnapshot.OwnedCard] = []
    @Published private(set) var cardCount = 0
    @Published private(set) var variantCount = 0
    @Published private(set) var deckCount = 0
    @Published private(set) var collectionLevel: Int?
    @Published private(set) var credits: Int?
    @Published private(set) var gold: Int?
    @Published private(set) var collectorsTokens: Int?
    @Published private(set) var wildBoosters: Int?
    @Published private(set) var boosterCount = 0
    @Published private(set) var lastChange: SnapshotHistoryStore.Change?
    @Published private(set) var sourcePath = "—"
    @Published private(set) var isConnecting = false
    @Published private(set) var isLinked = false
    @Published private(set) var isSyncing = false
    @Published private(set) var hasError = false
    @Published var automaticSyncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(automaticSyncEnabled, forKey: Self.automaticSyncKey)
            startAutomaticSync()
        }
    }

    var canConnect: Bool { source != nil }
    var canSync: Bool { source != nil && isLinked }

    private var source: SnapSource?
    private var scopedURL: URL?
    private var monitorTask: Task<Void, Never>?
    private let synchronizer: SnapSynchronizer
    private static let automaticSyncKey = "automaticSyncEnabled"

    init(synchronizer: SnapSynchronizer = SnapSynchronizer()) {
        self.synchronizer = synchronizer
        automaticSyncEnabled = UserDefaults.standard.object(forKey: Self.automaticSyncKey) as? Bool ?? true
    }

    func load() {
        isLinked = (try? KeychainTokenStore.load()) != nil

        if let bookmarkedURL = try? FolderBookmarkStore.restoreURL(),
           (try? loadSource(at: bookmarkedURL)) != nil {
            showReady()
            startAutomaticSync()
            return
        }

        do {
            guard let source = SnapSource.discover().first else {
                throw SnapSyncError.sourceNotFound
            }
            try loadSource(at: source.url)
            showReady()
            startAutomaticSync()
        } catch {
            show(error)
        }
    }

    func selectFolder(_ url: URL) {
        do {
            try loadSource(at: url, saveBookmark: true)
            showReady()
            startAutomaticSync()
        } catch {
            show(error)
        }
    }

    func synchronize() async {
        guard let source, isSyncing == false, isConnecting == false else { return }
        isSyncing = true
        statusText = "Sincronizando…"
        hasError = false
        defer { isSyncing = false }

        do {
            let refreshedSource = try SnapSource.inspect(at: source.url)
            let snapshot = try SnapshotIO.read(from: refreshedSource)
            update(snapshot, source: refreshedSource)
            switch try await synchronizer.synchronize(refreshedSource) {
            case .unchanged:
                statusText = "Já está atualizado"
            case .synchronized:
                statusText = "Sincronizado às \(Date.now.formatted(date: .omitted, time: .shortened))"
            }
        } catch is CancellationError {
            statusText = "Sincronização cancelada"
        } catch {
            show(error)
        }
    }

    func connect() async {
        guard let source, isConnecting == false, isSyncing == false else { return }
        isConnecting = true
        statusText = "Conectando ao MarvelSnap.pro…"
        hasError = false
        defer { isConnecting = false }

        do {
            let snapshot = try SnapshotIO.read(from: source)
            guard let account = snapshot.account,
                  let screenName = account.displayName,
                  screenName.isEmpty == false else {
                throw SnapSyncError.unsupportedSchema(
                    file: "ProfileState.json",
                    reason: "account name or ID is missing"
                )
            }

            let connection = try await MarvelSnapProClient().connectAccount(
                screenName: screenName,
                accountID: account.id
            ) { url in
                try await self.openConfirmationPage(url)
            }
            try KeychainTokenStore.save(connection.credential.token)
            isLinked = true
            statusText = "Conectado como \(connection.credential.nickname)"
            startAutomaticSync()
        } catch is CancellationError {
            statusText = "Conexão cancelada"
        } catch {
            show(error)
        }
    }

    func disconnect() {
        guard isConnecting == false, isSyncing == false else { return }
        do {
            try KeychainTokenStore.delete()
            isLinked = false
            startAutomaticSync()
            statusText = "Conta MarvelSnap.pro desconectada"
            hasError = false
        } catch {
            show(error)
        }
    }

    func clearLocalData() {
        guard isConnecting == false, isSyncing == false else { return }
        monitorTask?.cancel()
        monitorTask = nil

        do {
            try FolderBookmarkStore.clear()
            try SyncCheckpoint.clear()
            try SyncOutbox.remove()
            try SnapshotHistoryStore.clear()
            scopedURL?.stopAccessingSecurityScopedResource()
            scopedURL = nil
            source = nil
            accountName = "—"
            collection = []
            cardCount = 0
            variantCount = 0
            deckCount = 0
            collectionLevel = nil
            credits = nil
            gold = nil
            collectorsTokens = nil
            wildBoosters = nil
            boosterCount = 0
            lastChange = nil
            sourcePath = "—"
            statusText = "Dados locais removidos"
            hasError = false
        } catch {
            show(error)
            startAutomaticSync(synchronizeImmediately: false)
        }
    }

    private func update(_ snapshot: SnapSnapshot, source: SnapSource) {
        self.source = source
        accountName = snapshot.account?.displayName ?? "Conta desconhecida"
        collection = snapshot.collection
        cardCount = collection.count
        variantCount = collection.reduce(0) { $0 + $1.variants.count }
        deckCount = snapshot.decks.count
        collectionLevel = snapshot.inventory.collectionLevel
        credits = snapshot.inventory.credits
        gold = snapshot.inventory.gold
        collectorsTokens = snapshot.inventory.collectorsTokens
        wildBoosters = snapshot.inventory.wildBoosters
        boosterCount = collection.compactMap(\.boosters).reduce(0, +)
        do {
            lastChange = try SnapshotHistoryStore.record(snapshot)
        } catch {
            Logger(subsystem: "com.snapsync", category: "history").error("History update failed")
        }
        sourcePath = source.url.path
    }

    private func loadSource(at url: URL, saveBookmark: Bool = false) throws {
        let accessed = url.startAccessingSecurityScopedResource()
        do {
            let source = try SnapSource.inspect(at: url)
            let snapshot = try SnapshotIO.read(from: source)
            if saveBookmark { try FolderBookmarkStore.saveAccess(to: url) }
            scopedURL?.stopAccessingSecurityScopedResource()
            scopedURL = accessed ? url : nil
            update(snapshot, source: source)
        } catch {
            if accessed { url.stopAccessingSecurityScopedResource() }
            throw error
        }
    }

    private func showReady() {
        statusText = isLinked ? "Pronto para sincronizar" : "Conecte sua conta MarvelSnap.pro"
        hasError = false
    }

    private func startAutomaticSync(synchronizeImmediately: Bool = true) {
        monitorTask?.cancel()
        monitorTask = nil
        guard automaticSyncEnabled, isLinked, let source else { return }

        monitorTask = Task { [weak self] in
            do {
                let changes = try DirectoryMonitor.changes(at: source.url)
                let debouncer = ChangeDebouncer()
                if synchronizeImmediately {
                    await self?.synchronize()
                }

                for await _ in changes {
                    await debouncer.schedule { [weak self] in
                        await self?.synchronize()
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                self?.show(error)
            }
        }
    }

    private func openConfirmationPage(_ url: URL) throws {
        statusText = "Confirme o vínculo no navegador…"
        guard NSWorkspace.shared.open(url) else {
            throw SnapSyncError.invalidArguments("Não foi possível abrir a confirmação do MarvelSnap.pro")
        }
    }

    private func show(_ error: Error) {
        statusText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        hasError = true
    }

    deinit {
        monitorTask?.cancel()
        scopedURL?.stopAccessingSecurityScopedResource()
    }
}
