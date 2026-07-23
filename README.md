# SnapSync

SnapSync is a native macOS app and command-line tool that reads local Marvel Snap state files and synchronizes your account, collection, and decks with MarvelSnap.pro.

It reads game files without modifying them. No overlay, OCR, memory inspection, traffic interception, analytics, or telemetry is included.

> SnapSync is an unofficial community project. It is not affiliated with or endorsed by Marvel, Second Dinner, Nuverse, or MarvelSnap.pro.

## Features

- Automatic discovery of the Marvel Snap `States/nvprod` directory on macOS.
- Manual folder selection with a persistent read-only security-scoped bookmark.
- Versioned parsing of account, collection, variants, and decks.
- Local inventory summary with collection level, currencies, and card boosters.
- Searchable collection browser with owned/missing filters, grayscale missing cards, sorting, and cached artwork.
- Searchable deck browser with artwork previews and full card contents.
- Private lightweight history of the latest collection and deck changes.
- Manual and automatic synchronization with debounce, retry, idempotency, and an offline outbox.
- Native SwiftUI dashboard and menu bar controls.
- English and Brazilian Portuguese localization through a String Catalog.
- Keychain storage for the MarvelSnap.pro token.
- In-app account disconnection and local data cleanup.
- Sanitized diagnostics through `snapsync doctor`.
- Developer ID signing and Apple notarization through Fastlane and Match.

## Requirements

- macOS 13 or later.
- Swift 6.2 or later for development.
- A local Marvel Snap installation for discovery and synchronization.
- A MarvelSnap.pro account for uploads.

## Build and test

```bash
swift build
swift test
```

After editing `Localizable.xcstrings`, regenerate Swift symbols and package resources:

```bash
./scripts/update_localizations.sh
```

Run the development app:

```bash
swift run SnapSyncApp
```

Create a macOS application bundle or DMG:

```bash
./scripts/build_app.sh
./scripts/build_dmg.sh
```

Artifacts are written to the ignored `dist/` directory.

## CLI

```bash
swift run snapsync discover
swift run snapsync inspect
swift run snapsync export --output snapshot.json
swift run snapsync connect
swift run snapsync sync --dry-run
swift run snapsync sync --confirm
swift run snapsync watch --confirm
swift run snapsync doctor
```

Use `--path <nvprod>` with commands that accept a manually selected source directory.

## Release

Release credentials are never committed. `fastlane/Matchfile`, `.env` files, certificates, private keys, provisioning profiles, and build artifacts are ignored.

After configuring the local Matchfile and the `SnapSync-notary` Keychain profile:

```bash
mise install
mise exec -- bundle install
mise exec -- bundle exec fastlane mac release
```

See [DISTRIBUTION.md](DISTRIBUTION.md) for the complete release flow.

## Privacy

SnapSync reads `ProfileState.json` and `CollectionState.json` locally. Inventory and history remain on the Mac. Linking and synchronization send only the account, collection, deck, and authentication data required by MarvelSnap.pro. Tokens remain in the macOS Keychain, and private values are excluded from logs and diagnostics.

See [PRIVACY.md](PRIVACY.md) for the complete data-handling policy.

## Project status

The current milestone and remaining work are tracked in [ROADMAP.md](ROADMAP.md).

## License

SnapSync is available under the [MIT License](LICENSE).
