# ZTransfer

ZTransfer is a Flutter Android app for tethered shooting with Nikon Z Series
cameras. It connects over USB (PTP/MTP) or Wi-Fi (PTP/IP), automatically
downloads new JPEGs as they are captured, and organizes them into projects for
quick review and sharing.

The app uses a dark-only Material 3 interface with Nikon-yellow accents. The
native Android layer presents USB and Wi-Fi through a shared transport
abstraction, so the Flutter business logic does not depend on the active
connection type.

## Features

- USB OTG and Wi-Fi camera connections
- Automatic JPEG download after capture
- Transfer progress, camera battery, and storage status
- Project-based photo organization
- Full-screen photo review, selection, deletion, and sharing
- English and Simplified Chinese localization

## Requirements

- Flutter 3.24 or newer
- Dart 3.5 or newer
- Android device with USB host support
- JVM 17 for Android builds

ZTransfer is Android-only. Camera compatibility and end-to-end transfer should
be verified with the intended Nikon body and connection mode.

## Development

```bash
flutter pub get
flutter run
flutter test test/widget_test.dart
```

After changing Freezed, JSON, Riverpod models, or localization ARB files,
regenerate the derived sources before running the test:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Architecture

Flutter source lives in `lib/`. The native camera bridge is under
`android/app/src/main/kotlin/com/cacl2/ztransfer/`, with transport-specific code
in `camera/transport/`. Consult the local-only architecture and protocol notes
for details.

The static landing page is kept separately in `website/`.
