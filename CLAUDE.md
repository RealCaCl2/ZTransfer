# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

ZTransfer — a Flutter Android app for tethered shooting with Nikon Z Series cameras over USB. The app uses PTP (Picture Transfer Protocol) via a native Kotlin layer to detect the camera, auto-download JPEGs as they're shot, and organize them into projects. Dark-first Material 3 UI with Nikon yellow (`#FFD100`) as the accent.

## Build & run

```bash
# Run on a connected Android device/emulator
flutter run

# Run code generation (run after changing freezed/riverpod models)
dart run build_runner build --delete-conflicting-outputs

# Run the single widget test
flutter test test/widget_test.dart
```

## Architecture

### Platform layer (`lib/platform/`)

Abstract `CameraPlatform` interface with one Android implementation (`CameraMethodChannel`) registered in `main()` before `runApp()`. The native side communicates over two channels on `com.cacl2.ztransfer/camera`:

- **MethodChannel** — request/response calls: connect, disconnect, list photos, download, EXIF, project CRUD, share, delete.
- **EventChannel** — push-based stream for `CameraEvent` subtypes: `ObjectAddedEvent`, `ConnectionStateChangedEvent`, `TransferProgressEvent`, `LogEvent`.

A `_DefaultCameraPlatform` fallback returns safe defaults (empty lists, `false`, `null`) so the UI never crashes when the platform isn't available (e.g. running on iOS during development).

### Features (feature-first structure in `lib/features/`)

Each feature follows a `data/` (models, repositories) + `presentation/` (notifiers, screens, widgets) split:

- **camera** — USB connection lifecycle. `CameraNotifier` (code-generated via `@riverpod`) manages `CameraConnectionStatus` enum (disconnected/connecting/connected/error) and reacts to `ConnectionStateChangedEvent` from the event stream. `CameraRepository` is a thin wrapper over `CameraPlatform` for testability.
- **gallery** — Photo listing and viewing. `GalleryNotifier` is a manual `StateNotifier` (not `@riverpod`) because it needs to listen to gallery events in its constructor — `build()` lifecycle constraints make `@riverpod` awkward for async init. `PhotoItem` is a freezed model with `objectHandle`, `fileName`, `localPath`, etc. `GalleryRepository` wraps platform calls for photo listing/deletion.
- **sync** — The auto-download pipeline. `SyncNotifier` (`@riverpod`) listens for `ObjectAddedEvent` from the native event stream, creates a `PhotoItem`, and inserts it into `GalleryNotifier` via `addSyncedPhoto()`. The native layer already downloaded the file — Flutter just updates UI state.
- **project** — Organizational units for photo shoots. `ProjectNotifier` is a manual `StateNotifier` that wraps `CameraRepository` for CRUD operations. `Project` is a hand-written model (not freezed) with `fromMap`/`copyWith`.

### Routing (`lib/app_router.dart`)

GoRouter with 4 routes and a shared slide+fade page transition (`CustomTransitionPage`):

| Path | Screen | Notes |
|------|--------|-------|
| `/` | `HomeScreen` | Gallery grid + camera status + sync bar |
| `/projects` | `ProjectListScreen` | CRUD for projects |
| `/phone` | `PhoneGalleryScreen` | Full local gallery with multi-select |
| `/detail/:objectHandle` | `ImageDetailScreen` | Swipeable, pinch-to-zoom with EXIF overlay |

The detail route receives the full photo list as `state.extra` to support swipe navigation.

### State management

Riverpod with two patterns:

1. **`@riverpod` + code generation** — Used for `CameraNotifier` and `SyncNotifier`. Generates `.g.dart` files. These notifiers use `build()` for one-time setup and `ref.onDispose()` for cleanup.
2. **Manual `StateNotifier`** — Used for `GalleryNotifier` and `ProjectNotifier`. Avoids `build()` lifecycle constraints when async init or cross-notifier listening is needed in the constructor via `ref.listen()`.

`app.dart` wraps everything in `ProviderScope` at the root.

### Code generation

Three generators in play — all require `build_runner`:

- **freezed** — immutable data classes (`PhotoItem`). Generates `.freezed.dart` with `copyWith`, `==`, `hashCode`, `toString`.
- **json_serializable** — JSON serialization. Generates `.g.dart` with `fromJson`/`toJson`.
- **riverpod_generator** — provider code for `@riverpod` annotated classes. Generates `.g.dart` with the provider variable.

Generated files are excluded from the analyzer in `analysis_options.yaml`.

### Native Android layer (`app/src/main/java/com/example/ptpdemo/`)

- `MainActivity.kt` — entry point, sets up Flutter engine with method/event channel handlers.
- `PtpManager.kt` — the PTP protocol implementation: USB device enumeration, session open/close, object listing, file download, EXIF extraction.
- `ui/` — legacy compose UI (not used; Flutter is the UI layer).

### Theme (`lib/core/theme/`)

Dark-only in practice (light variant exists but the app forces `ThemeMode.dark`). Tokens in `AppColors`: five surface levels, three text levels, four status colors. Typography in `AppTypography` uses the system font (Roboto on Android).

## Key patterns

- All platform calls are wrapped in try/catch in `CameraMethodChannel` — failures return safe defaults, never throw.
- The native `PtpManager` auto-downloads photos when the camera fires the shutter. Flutter only reacts to the `ObjectAddedEvent` that arrives after download completes — it never initiates a download itself during normal shooting.
- `GalleryRepository` is a shared singleton via `galleryRepositoryProvider` — `SyncNotifier` and `GalleryNotifier` share the same event stream subscription pattern but listen independently.
- Selection mode (multi-select for delete/share) is implemented with local `Set<String>` state keyed by `localPath` in both `HomeScreen` and `PhoneGalleryScreen` — not global state.
