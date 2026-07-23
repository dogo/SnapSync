# SnapSync Privacy Policy

Last updated: July 23, 2026.

SnapSync does not use analytics, telemetry, advertising, or collect data of its own.

## Data read locally

The app locates, or uses a folder you select, and reads the Marvel Snap `ProfileState.json` and `CollectionState.json` files without modifying them. It extracts:

- account ID and name;
- collection and variants;
- decks, deck names, and cards;
- collection level, currencies, and card boosters.

The folder path and complete source files are not uploaded.

## Data sent to MarvelSnap.pro

When linking an account, SnapSync sends the account name, account ID, and time zone offset to MarvelSnap.pro. When synchronizing, it sends:

- account ID;
- collection and variants;
- decks, deck names, and cards;
- the authentication token required to validate the account.

Outside the account-linking flow described above, no synchronization data is sent until the account is linked. Automatic synchronization can be disabled from the dashboard or the app menu.

## Data stored on your Mac

- The MarvelSnap.pro token is stored in Keychain under the `com.snapsync.marvelsnappro` service.
- Access to the selected folder is stored as a read-only security-scoped bookmark.
- The local checkpoint contains the snapshot hash, timestamp, and account ID.
- The lightweight history stores the latest normalized snapshot and the latest collection or deck change.
- If an upload fails, the outbox retains only the latest pending snapshot until synchronization succeeds.
- The bookmark, checkpoint, history, and outbox use local `0600` permissions.
- Logs do not include the token, folder path, account, collection, or deck names.

These files are stored in `~/Library/Application Support/SnapSync`. They can be removed from the dashboard or deleted while the app is closed. The token can be removed with the app's disconnect action or through Keychain Access by searching for the service name above.

## Third party

MarvelSnap.pro receives the data required for account linking and synchronization and applies its own privacy practices. SnapSync does not share this data with any other destination.
