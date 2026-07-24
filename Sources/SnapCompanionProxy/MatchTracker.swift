import Foundation

/// Parses the game's WebSocket messages (GetChangesResponse changes) to track
/// the opponent's revealed cards. Swift port of spike/snap_tracker.py.
final class MatchTracker {
    private var me: String?
    private var players: [Int: String] = [:]   // player entityId -> account id
    private var cardOwner: [Int: Int] = [:]     // card entityId -> owner (player) entityId
    private var revealed: [Int: String] = [:]   // card entityId -> CardDefId

    /// Returns the opponent's revealed cards if this message changed them.
    func process(_ message: Data) -> [String]? {
        guard let obj = try? JSONSerialization.jsonObject(with: message) as? [String: Any] else { return nil }
        if (obj["$type"] as? String)?.contains("ChangeNotification") == true,
           let account = obj["AccountId"] as? String {
            me = account
        }
        var changed = false
        for change in (obj["Changes"] as? [[String: Any]]) ?? [] {
            let type = change["$type"] as? String ?? ""
            if type.contains("GameCreateChange") {
                reset()
            } else if type.contains("GameCreatePlayerChange") {
                if let id = change["EntityId"] as? Int {
                    players[id] = (change["PlayerInfo"] as? [String: Any])?["AccountId"] as? String
                }
            } else if type.contains("GameCreateCardChange") {
                if let id = change["EntityId"] as? Int, let owner = change["OwnerEntityId"] as? Int {
                    cardOwner[id] = owner
                }
            } else if type.contains("GameRevealCardChange") {
                if let id = change["EntityId"] as? Int, let def = change["CardDefId"] as? String {
                    revealed[id] = def
                    changed = true
                }
            }
        }
        return changed ? opponentCards() : nil
    }

    private func reset() {
        players.removeAll(); cardOwner.removeAll(); revealed.removeAll()
    }

    private var opponentEntity: Int? {
        players.first { $0.value != nil && $0.value != me }?.key
    }

    private func opponentCards() -> [String] {
        guard let opponent = opponentEntity else { return [] }
        var seen = Set<String>()
        var cards: [String] = []
        for (id, def) in revealed where cardOwner[id] == opponent && seen.insert(def).inserted {
            cards.append(def)
        }
        return cards
    }
}
