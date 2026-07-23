# Distribution

The local ad hoc build does not require credentials:

```bash
./scripts/build_dmg.sh
```

To publish a release, install Ruby and Fastlane:

```bash
mise install
mise exec -- bundle install
```

`fastlane/Matchfile` is a local configuration file ignored by Git. Configure it with your certificate repository, Team ID, and Apple ID. The **Developer ID Application** certificate is already stored in the certificate repository; on a new machine, install it in read-only mode:

```bash
mise exec -- bundle exec fastlane mac certificates
```

Use `bootstrap_certificates` only when the certificate repository does not contain a valid Developer ID certificate, because this lane creates the certificate in the Apple Developer portal and stores an encrypted copy in the repository.

Store the notarization credentials directly in Keychain as well:

```bash
xcrun notarytool store-credentials SnapSync-notary
```

This command prompts for the Apple ID, Team ID, and app-specific password without writing them to the repository. Once the profile is stored, build the complete release:

```bash
mise exec -- bundle exec fastlane mac release
```

Fastlane installs the existing certificate without modifying it. The native pipeline then rebuilds and signs the app and DMG with the hardened runtime, submits the DMG to Apple, staples the ticket, and validates it with Gatekeeper.
