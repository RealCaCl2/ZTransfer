// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'camera_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$cameraRepositoryHash() => r'85fa81b216715068446e46c9402b45a9fc073346';

/// See also [cameraRepository].
@ProviderFor(cameraRepository)
final cameraRepositoryProvider = AutoDisposeProvider<CameraRepository>.internal(
  cameraRepository,
  name: r'cameraRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$cameraRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CameraRepositoryRef = AutoDisposeProviderRef<CameraRepository>;
String _$cameraNotifierHash() => r'a3befce3400e9169295017773ce698a13015a6f3';

/// Manages the USB camera connection lifecycle.
///
/// Listens to [CameraPlatform.eventStream] for connection-state changes
/// pushed from the native layer, so the UI reflects reality without polling.
///
/// Copied from [CameraNotifier].
@ProviderFor(CameraNotifier)
final cameraNotifierProvider =
    AutoDisposeNotifierProvider<CameraNotifier, CameraState>.internal(
  CameraNotifier.new,
  name: r'cameraNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$cameraNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CameraNotifier = AutoDisposeNotifier<CameraState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
