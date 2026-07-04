# Spoiler Delay

<p align="center">
  <img src="Resources/AppIcon.svg" width="144" alt="Spoiler Delay soccer ball clock icon">
</p>

Spoiler Delay is a native macOS menu-bar app that replaces Messages notifications and delays them while you watch a World Cup stream. It reads Messages locally, never uploads message content, and never displays match scores.

## Requirements

- macOS 15 or newer
- Full Disk Access, notification permission, and native Messages notifications disabled
- Optional Contacts access for familiar sender names

## Build

```sh
swift test
chmod +x Scripts/*.sh
Scripts/build-app.sh
open "build/Spoiler Delay.app"
```

For regular use, move the app to `/Applications` before opening it. The first run walks through every permission. Full Disk Access cannot be granted programmatically; after granting it, quit and reopen the app. Keep Spoiler Delay running at login because native Messages notifications are replaced by this app.

## Release signing

`Scripts/build-app.sh` ad-hoc signs local builds. For a public GitHub release, first store notary credentials with `xcrun notarytool store-credentials`, then run:

```sh
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_KEYCHAIN_PROFILE="spoiler-delay-notary" \
Scripts/notarize-release.sh
```

Without Developer ID signing and notarization, Gatekeeper will warn other users about the downloaded build.

## Privacy and limitations

- Message bodies remain on the Mac. Cursor and session state are persisted; bodies are not.
- The FIFA feed is an undocumented public endpoint used by FIFA's site. If it becomes unavailable, the app falls back to an editable estimated end time.
- Notification timing is bounded by Messages sync latency, FIFA feed latency, and polling intervals.
- V1 opens Messages when a notification is clicked; inline replies and direct conversation navigation are not included.
