# AGENTS.md

High-signal notes for working in this repo. `CLAUDE.md` exists too, but some of its native-layer and route details are **outdated** — trust this file for those, and trust `CLAUDE.md` for the deeper Flutter feature/state-management walkthrough.

## Project

ZTransfer — Flutter Android app for tethered shooting with Nikon Z Series cameras. Connects over **USB (PTP/MTP)** or **Wi-Fi (PTP/IP)**, auto-downloads JPEGs as they're shot, and organizes them into projects. Dark-only Material 3 UI, Nikon yellow `#FFD100` accent.

- App id / Kotlin package: `com.cacl2.ztransfer`
- Gradle root project is named `PTPDemo` (historical) — not "ztransfer". Don't let that throw you.
- Not iOS-supported; an iOS run is a safe fallback (no native channel, see below).
- There is no `git` repo initialized here when working via the agent; `.gitignore` exists.

## Commands

```bash
flutter run                                  # run on connected Android device/emulator (USB OTG device expected)
flutter test test/widget_test.dart           # the ONLY test — a single smoke test
dart run build_runner build --delete-conflicting-outputs   # regenerate after editing freezed/riverpod/json models AND after editing l10n .arb files
flutter gen-l10n                             # alternatively, regen localizations alone
```

There is no separate `lint`/`typecheck` script — `flutter analyze` uses `analysis_options.yaml` (extends `flutter_lints`). No CI workflow checked in; no pre-commit config. `flutter run` builds the Gradle Android project automatically.

Required order when you change models: **edit `.dart`/`.arb` → `build_runner` → `flutter test`**. The test relies on generated code compiling.

## Code generation (three generators, all via build_runner)

- **freezed** → `*.freezed.dart` (immutable models: `PhotoItem`)
- **json_serializable** → `*.g.dart` (`fromJson`/`toJson`)
- **riverpod_generator** → `*.g.dart` (provider vars for `@riverpod` notifiers)

Generated files are **excluded from the analyzer** in `analysis_options.yaml` (`*.g.dart`, `*.freezed.dart`, `lib/generated/**`). Never hand-edit them. If analyzer noise appears after a build_runner run, regenerate, don't `// ignore`.

## Localization (i18n — NOT in CLAUDE.md)

- `l10n.yaml` drives generation: ARB files in `lib/l10n/` (`app_en.arb` template), output to `lib/l10n/generated/`.
- `pubspec.yaml` has `flutter: generate: true`, so `flutter pub get` / build triggers it.
- Two locales: **en** (template) and **zh**. UI strings must be localized — add to both ARB files. Some `.dart` still in `lib/l10n/` are hand-maintained pre-generation artifacts; the `generated/` subfolder is the real output.

## Architecture

### Platform bridge (the part CLAUDE.md gets stale)

Native Kotlin lives at **`android/app/src/main/kotlin/com/cacl2/ztransfer/`** — NOT `app/src/main/java/com/example/ptpdemo/` as CLAUDE.md says. Package is `com.cacl2.ztransfer`, not `com.example.ptpdemo`.

Native structure (Kotlin):
```
com/cacl2/ztransfer/
├── MainActivity.kt                 # entry, USB broadcast receiver, channel setup
├── camera/
│   ├── CameraChannelHandler.kt      # method/event channel dispatch — transport-agnostic
│   ├── PtpManager.kt                # USB PTP/MTP protocol (the original impl)
│   ├── ProjectStore.kt              # native persistence for projects
│   └── transport/
│       ├── CameraTransport.kt        # unified interface (USB + Wi-Fi) + shared types
│       ├── TransportEvent.kt        # sealed event class
│       ├── UsbTransport.kt           # adapter wrapping PtpManager
│       ├── WifiTransport.kt          # PTP/IP over TCP (dual cmd+evt sockets)
│       ├── CameraScanner.kt
│       ├── CameraMdnsDiscovery.kt   # mDNS/Bonjour camera discovery
│       ├── NetworkProbe.kt
│       └── PtpIpConstants.kt
```

Key invariant: **business logic doesn't know the transport.** `CameraTransport` abstracts USB and Wi-Fi identically; `CameraChannelHandler` routes to the active one (`activeTransport`). One transport is active at a time. `connectAuto()` tries USB first, falls back to Wi-Fi. Consult the local-only architecture and protocol notes before changing the transport layer.

### Platform channels (Dart ↔ Kotlin)

- Channel names live in `lib/core/constants/app_constants.dart` (`AppConstants.platformChannelName`). The base is `com.cacl2.ztransfer/camera`; EventChannel is `<base>/events`.
- `main.dart` registers `CameraMethodChannel` **before** `runApp()`. Platform calls all try/catch and return safe defaults — the UI never throws on missing native (iOS dev path uses `_DefaultCameraPlatform`).
- Native **auto-downloads** photos on capture. Flutter only reacts to the resulting `ObjectAddedEvent` (which already carries `localPath`); it does **not** initiate downloads during normal shooting.

### Camera events (sealed, in `camera_platform_interface.dart`)

`ObjectAddedEvent`, `ConnectionStateChangedEvent`, `TransferProgressEvent`, `LogEvent`, `ObjectRemovedEvent`, `BatteryChangedEvent`, `StorageChangedEvent`. CLAUDE.md only lists the first four — the battery/storage events drive the newer Wi-Fi transport status UI.

### State management (two patterns — intentional)

1. `@riverpod` + codegen — `CameraNotifier`, `SyncNotifier`. Use `build()` for one-time setup and `ref.onDispose()` for cleanup.
2. Manual `StateNotifier` — `GalleryNotifier`, `ProjectNotifier`. Chosen deliberately because they need async init / cross-notifier `ref.listen()` in the constructor, which `@riverpod`'s `build()` lifecycle makes awkward. Don't "modernize" these to `@riverpod` without that constraint in mind.

### Routing (`app_router.dart`, GoRouter)

**5 routes** (CLAUDE.md says 4 — it omits `/about`): `/` (HomeScreen), `/projects`, `/phone` (PhoneGalleryScreen), `/about`, `/detail/:objectHandle`. The detail route takes the full `List<PhotoItem>` via `state.extra` for swipe navigation. Shared slide+fade transition; detail uses a distinct fade-only transition.

### Selection mode

Multi-select for delete/share is local `Set<String>` state keyed by `localPath` in `HomeScreen` and `PhoneGalleryScreen` — **not** global Riverpod state. Don't lift it into a provider unless those screens actually need to share selection.

## Android build quirks

- Release signing reads `key.properties` at the **root** (`keystoreProperties`). A release build without that file will still build but be unsigned.
- Release has **`isMinifyEnabled = true` and `isShrinkResources = true`** — `proguard-rules.pro` keeps `io.flutter.**`, `kotlinx.coroutines.**`, `android.hardware.usb.**`, `android.mtp.**`, `FileProvider`, and the whole `com.cacl2.ztransfer.**` package. Adding reflective/serialization classes → add keep rules or R8 will strip them.
- **ABI split**: release packaging excludes `armeabi-v7a` and `x86_64`, shipping `arm64-v8a` only (USB OTG target devices are arm64). This cuts ~48MB → ~17MB. Don't re-enable other ABIs expecting emulator parity.
- Java/Kotlin target: **JVM 17**.
- `AndroidManifest.xml`: `android.hardware.usb.host` is a **required** feature; the app **auto-launches on USB camera attach** (`USB_DEVICE_ATTACHED` intent-filter + `res/xml/device_filter.xml`). Networking permissions (INTERNET, WIFI state, CHANGE_WIFI_MULTICAST_STATE) are for Wi-Fi/mDNS. A `FileProvider` (authority `${applicationId}.fileprovider` + `res/xml/file_paths`) backs the share sheet.

## The (only) test

`test/widget_test.dart` is a single smoke test: pumps `ZTransferApp`, asserts `find.text('ZTransfer')` exists **once** and `find.text('No Camera')` (the disconnected status) exists. If your change alters the home title text or the disconnected status string, update this test or it will fail — that is the test's real purpose, not a coincidence.

## Repo layout extras (not part of the app)

- Internal architecture and protocol notes are local-only and excluded by `.gitignore`; consult them before touching the transport layer.
- `website/index.html` + `Caddyfile` — a static landing page served by Caddy at `ztransfer.cacl2.top`; not part of the Flutter build.
- `bridge/` — empty directory; ignore.
