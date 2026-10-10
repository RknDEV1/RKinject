# Raki

SwiftUI iPhone app (iOS 18+): file browser, plist editor and a package library
(patches, wallpapers, dialer themes) with install/update status.

## Build

1. `brew install xcodegen`
2. `xcodegen generate` and open `Raki.xcodeproj` (Xcode 16 or newer).
3. Pick your team under Signing & Capabilities and run.

Dependency: [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) (Swift Package Manager, resolved by Xcode).

## What it does

- **Sources**: this app's Documents, Library, Imported and Installed content, optional App Groups,
  plus custom absolute paths. Search (recursive), Quick Look preview, sort, hidden files toggle.
- **File actions**: copy, move (clipboard + "Paste here"), rename, delete, import, share, zip, unzip, new folder.
- **Plist editor**: edit strings, numbers, booleans and dates; add/remove entries; nested dictionaries and arrays.
  Saves in the original format (XML or binary).
- **Discover / Installed**: download (with progress), checksum check, unzip, version tracking, update indicators.
- **Languages**: English, Português (Brasil), Tiếng Việt, 简体中文. Follows the per-app language in iOS Settings.

## Real limits to know

- iOS sandboxes apps. Out of the box Raki only sees its own container. Other apps' data and App Group
  containers need access the system grants (App Group entitlement for groups you own, or a device/signing setup
  that allows broader access). When access is denied, the app shows a clear "permission" message.
- To list App Groups: add the identifiers to `RakiAppGroups` in `project.yml` and add the matching
  App Groups capability in Xcode.

## Content catalog

Default: `Resources/catalog.json` with three sample packages shipped in `Resources/Samples`
(URLs like `bundle://raki-aurora.zip`). To use your own server, put a JSON file at an https URL in
Settings. Format:

```json
{ "packages": [{
  "id": "wallpaper.aurora", "name": "Aurora", "kind": "wallpaper",
  "version": "1.1", "size": 30533, "author": "You",
  "summary": "…", "url": "https://…/aurora.zip", "sha256": "optional hex digest"
}] }
```

`kind` is `patch`, `wallpaper` or `dialerTheme`. Installed packages unzip into
Application Support/Raki/Installed/<id>. Raki stores and manages content; it does not apply patches to other apps.
