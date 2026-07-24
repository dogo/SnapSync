# Spike: live opponent tracking

Exploratory work toward showing the opponent's deck live during a match.

## Findings

- **Local files don't have live state.** `GameState.json` is an empty shell
  during a match; it's only filled at match end. No file updates per turn.
- **Live state is on a WebSocket**, direct TLS socket that bypasses the system
  HTTP proxy (so Charles can't see it). Host: `*-ws-cf.nvprod.snapgametech.com`,
  path `/v55.8-4-game`. **No cert pinning** — decrypts cleanly.
- **The channel is plain JSON.** Client sends `GetChangesRequest`; server
  answers `GetChangesResponse` with incremental `Changes[]`:
  - `GameCreatePlayerChange` → player `EntityId` ↔ `AccountId`.
  - `GameCreateCardChange` → card `EntityId` + `OwnerEntityId` (which player).
  - `GameRevealCardChange` → card `EntityId` + `CardDefId` (+ Cost/Power).
  Join owner + reveal → the opponent's revealed cards, live, exact.
- **Deck prediction** works off MarvelSnap.pro `do.php?cmd=getmeta` (20
  archetypes with weighted `structure`). Match revealed cards → archetype →
  predict the unrevealed rest.

## Contents

- `snap_tracker.py` — mitmproxy addon; parses the `-game` WebSocket and surfaces
  the opponent's revealed cards. Testable offline by replaying a captured
  `flows.mitm`.
- `predict.py` — ranks archetypes by coverage of the revealed cards and lists
  the likely-remaining cards.

## Interception, proven paths

- **mitmproxy `--mode local:SNAP`** (macOS 11+ redirector system extension)
  captures the game's WebSocket with no pinning. Used for this investigation.
- **NETransparentProxyProvider** (`Sources/SnapCompanionProxy`) — native system
  extension embedded in the app. Builds, embeds, and signs with the required
  entitlements. Blocked at launch on macOS 26 without **notarization** and an
  Apple-authorized `com.apple.developer.networking.networkextension` entitlement
  for Developer ID. That's the remaining productization gate.
