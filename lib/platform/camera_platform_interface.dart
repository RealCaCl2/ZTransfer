import 'dart:async';

/// Event payload pushed from the native PTP layer to Flutter.
sealed class CameraEvent {
  const CameraEvent();
}

class ObjectAddedEvent extends CameraEvent {
  final int objectHandle;
  final int formatCode;
  final String fileName;
  final int sizeBytes;
  final String? localPath;
  final int? width;
  final int? height;
  final bool isRaw;

  const ObjectAddedEvent({
    required this.objectHandle,
    required this.formatCode,
    required this.fileName,
    required this.sizeBytes,
    this.localPath,
    this.width,
    this.height,
    this.isRaw = false,
  });
}

class ConnectionStateChangedEvent extends CameraEvent {
  final bool connected;
  final String? deviceName;
  final String? transportType;

  const ConnectionStateChangedEvent({
    required this.connected,
    this.deviceName,
    this.transportType,
  });
}

class TransferProgressEvent extends CameraEvent {
  final int objectHandle;
  final double progress; // 0.0 – 1.0
  final int bytesTransferred;
  final int totalBytes;
  final double bytesPerSecond;

  const TransferProgressEvent({
    required this.objectHandle,
    required this.progress,
    required this.bytesTransferred,
    required this.totalBytes,
    required this.bytesPerSecond,
  });
}

class TransferStateChangedEvent extends CameraEvent {
  final bool listening;

  const TransferStateChangedEvent({required this.listening});
}

class LogEvent extends CameraEvent {
  final String level; // "INFO" | "EVENT" | "ERROR"
  final String message;

  const LogEvent({required this.level, required this.message});
}

class ObjectRemovedEvent extends CameraEvent {
  final int objectHandle;
  const ObjectRemovedEvent({required this.objectHandle});
}

class BatteryChangedEvent extends CameraEvent {
  final int level; // 0-100
  const BatteryChangedEvent({required this.level});
}

class StorageChangedEvent extends CameraEvent {
  final int freeSpaceBytes;
  final int maxCapacityBytes;
  final int freeImages;
  const StorageChangedEvent({
    required this.freeSpaceBytes,
    required this.maxCapacityBytes,
    required this.freeImages,
  });
}

/// ──────────────────────────────────────────────────────────────────────────────
/// Abstract platform interface for camera operations.
///
/// The Android implementation communicates with the native Kotlin PTP layer
/// via MethodChannel.  All methods return reasonable defaults when the
/// platform is unavailable (e.g. on iOS during development).
/// ──────────────────────────────────────────────────────────────────────────────

abstract class CameraPlatform {
  static CameraPlatform? _instance;

  static CameraPlatform get instance {
    _instance ??= _DefaultCameraPlatform();
    return _instance!;
  }

  static set instance(CameraPlatform impl) => _instance = impl;

  /// Whether a camera is currently connected and the PTP session is open.
  Future<bool> isConnected();

  /// Request connection to a currently-attached camera.
  /// Returns the device name on success, `null` on failure.
  Future<String?> connect();

  /// Tear down the PTP session.

  /// Broadcast stream of PTP events (ObjectAdded, state changes, logs).
  Stream<CameraEvent> get eventStream;

  /// List JPEGs currently on the camera.
  Future<List<Map<String, dynamic>>> listCameraPhotos();

  /// Download a single JPEG from the camera by its object handle.
  /// Returns local file path on success.
  Future<String?> downloadPhoto(int objectHandle);

  /// List locally-synced JPEGs, optionally scoped to a project.
  Future<List<Map<String, dynamic>>> listLocalPhotos({String? projectId});

  /// Delete a locally-synced photo.
  Future<bool> deleteLocalPhoto(String filePath);

  /// Request the current EXIF metadata for a locally-synced photo.
  Future<Map<String, dynamic>?> getExifData(String filePath);

  /// Share a local JPEG file via the Android share sheet.
  Future<bool> shareFile(String filePath);

  /// Share multiple local JPEG files via ACTION_SEND_MULTIPLE.
  Future<bool> shareMultipleFiles(List<String> filePaths);

  /// Delete multiple local photos. Returns count deleted.
  Future<int> deleteMultiplePhotos(List<String> filePaths);

  // ── Project CRUD ────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listProjects();
  Future<Map<String, dynamic>?> createProject(String name);
  Future<bool> updateProject(String id, String name);
  Future<bool> deleteProject(String id, bool deletePhotos);
  Future<bool> setActiveProject(String? id);
  Future<Map<String, dynamic>?> getActiveProject();

  /// List ALL local photos (all projects + legacy).
  Future<List<Map<String, dynamic>>> listAllLocalPhotos();

  /// The currently active transport type ("USB", "WIFI"), or null.
  Future<String?> getTransportType();

  /// Query camera battery level (0-100), or null if unsupported.
  Future<int?> getBatteryLevel();

  /// Query camera storage info, or null if unsupported.
  Future<Map<String, dynamic>?> getStorageInfo();
}

/// Fallback implementation that returns defaults — used when the native
/// channel hasn't been set up yet (avoids null checks everywhere).
class _DefaultCameraPlatform extends CameraPlatform {
  @override
  Future<bool> isConnected() async => false;

  @override
  Future<String?> connect() async => null;

  @override
  @override
  Stream<CameraEvent> get eventStream => const Stream.empty();

  @override
  Future<List<Map<String, dynamic>>> listCameraPhotos() async => [];

  @override
  Future<String?> downloadPhoto(int objectHandle) async => null;

  @override
  Future<List<Map<String, dynamic>>> listLocalPhotos({
    String? projectId,
  }) async =>
      [];

  @override
  Future<bool> deleteLocalPhoto(String filePath) async => false;

  @override
  Future<Map<String, dynamic>?> getExifData(String filePath) async => null;

  @override
  Future<bool> shareFile(String filePath) async => false;

  @override
  Future<bool> shareMultipleFiles(List<String> filePaths) async => false;

  @override
  Future<int> deleteMultiplePhotos(List<String> filePaths) async => 0;

  @override
  Future<List<Map<String, dynamic>>> listProjects() async => [];
  @override
  Future<Map<String, dynamic>?> createProject(String name) async => null;
  @override
  Future<bool> updateProject(String id, String name) async => false;
  @override
  Future<bool> deleteProject(String id, bool deletePhotos) async => false;
  @override
  Future<bool> setActiveProject(String? id) async => false;
  @override
  Future<Map<String, dynamic>?> getActiveProject() async => null;
  @override
  Future<List<Map<String, dynamic>>> listAllLocalPhotos() async => [];

  @override
  Future<String?> getTransportType() async => null;

  @override
  Future<int?> getBatteryLevel() async => null;

  @override
  Future<Map<String, dynamic>?> getStorageInfo() async => null;
}
