// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_status_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$syncNotifierHash() => r'b1d0853cce51a6f3ab0a203ace2b9db2483500fe';

/// ──────────────────────────────────────────────────────────────────────────────
/// Watches the native event stream for [ObjectAddedEvent] and orchestrates
/// the "shoot → download → display" pipeline.
///
/// This is the Flutter-side counterpart of the native PtpManager event loop.
/// It does NOT re-implement PTP — it only reacts to events the native layer
/// pushes up.
/// ──────────────────────────────────────────────────────────────────────────────
///
/// Copied from [SyncNotifier].
@ProviderFor(SyncNotifier)
final syncNotifierProvider =
    AutoDisposeNotifierProvider<SyncNotifier, SyncState>.internal(
  SyncNotifier.new,
  name: r'syncNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$syncNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SyncNotifier = AutoDisposeNotifier<SyncState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
