"""Snap live match tracker — parses the -game WebSocket JSON to surface the
opponent's revealed cards. Runs as a mitmproxy addon (live) and is unit-testable
via process_message() against captured flows."""
import json


class MatchTracker:
    def __init__(self):
        self.me = None                 # my account id (recipient of ChangeNotifications)
        self.players = {}              # player entityId -> account id
        self.card_owner = {}           # card entityId -> owner (player) entityId
        self.revealed = {}             # card entityId -> CardDefId

    def process_message(self, text):
        try:
            obj = json.loads(text)
        except ValueError:
            return
        # ChangeNotifications arrive top-level, addressed to my account.
        if "ChangeNotification" in obj.get("$type", "") and obj.get("AccountId"):
            self.me = obj["AccountId"]
        for ch in obj.get("Changes") or []:
            t = ch.get("$type", "")
            if "ChangeNotification" in t and ch.get("AccountId"):
                self.me = ch["AccountId"]
            elif "GameCreatePlayerChange" in t:
                self.players[ch.get("EntityId")] = ch.get("PlayerInfo", {}).get("AccountId")
            elif "GameCreateCardChange" in t:
                self.card_owner[ch.get("EntityId")] = ch.get("OwnerEntityId")
            elif "GameRevealCardChange" in t and ch.get("CardDefId"):
                self.revealed[ch.get("EntityId")] = ch["CardDefId"]

    @property
    def opponent_entity(self):
        for eid, acct in self.players.items():
            if acct and acct != self.me:
                return eid
        return None

    def opponent_cards(self):
        opp = self.opponent_entity
        if opp is None:
            return []
        seen, out = set(), []
        for eid, defid in self.revealed.items():
            if self.card_owner.get(eid) == opp and defid not in seen:
                seen.add(defid)
                out.append(defid)
        return out


# --- mitmproxy addon glue (live) ---
tracker = MatchTracker()


def websocket_message(flow):
    if "-ws-cf" not in flow.request.pretty_host or "-game" not in flow.request.path:
        return
    msg = flow.websocket.messages[-1]
    if msg.from_client:
        return
    tracker.process_message(msg.content.decode("utf-8", "replace"))
    print("opponent revealed:", tracker.opponent_cards())
