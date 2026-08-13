import 'dart:async';
import 'package:ztransfer/platform/camera_method_channel.dart';
import 'package:ztransfer/platform/camera_platform_interface.dart';

/// Repository that wraps the platform-specific camera transport.
///
/// This is intentionally thin — the native PTP layer owns all protocol logic.
/// The repository only exists so that notifiers don't depend directly on
/// [CameraPlatform], making it easy to inject test doubles later.
class CameraRepository {
  final CameraPlatform _platform;

  CameraRepository({CameraPlatform? platform})
      : _platform = platform ?? CameraPlatform.instance;

  // ── connection ───────────────────────────────────────────────────────────

  Future<bool> isConnected() => _platform.isConnected();

  Future<String?> connect() => _platform.connect();

  // ── events ───────────────────────────────────────────────────────────────

  Stream<CameraEvent> get eventStream => _platform.eventStream;

  // ── camera photos ────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listCameraPhotos() =>
      _platform.listCameraPhotos();

  Future<String?> downloadPhoto(int objectHandle) =>
      _platform.downloadPhoto(objectHandle);

  // ── local photos ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listLocalPhotos({String? projectId}) =>
      _platform.listLocalPhotos(projectId: projectId);

  Future<List<Map<String, dynamic>>> listAllLocalPhotos() =>
      _platform.listAllLocalPhotos();

  Future<bool> deleteLocalPhoto(String filePath) =>
      _platform.deleteLocalPhoto(filePath);

  Future<Map<String, dynamic>?> getExifData(String filePath) =>
      _platform.getExifData(filePath);

  Future<bool> shareFile(String filePath) => _platform.shareFile(filePath);

  Future<bool> shareMultipleFiles(List<String> filePaths) =>
      _platform.shareMultipleFiles(filePaths);

  Future<int> deleteMultiplePhotos(List<String> filePaths) =>
      _platform.deleteMultiplePhotos(filePaths);

  // ── Projects ────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listProjects() => _platform.listProjects();

  Future<Map<String, dynamic>?> createProject(String name) =>
      _platform.createProject(name);

  Future<bool> updateProject(String id, String name) =>
      _platform.updateProject(id, name);

  Future<bool> deleteProject(String id, bool deletePhotos) =>
      _platform.deleteProject(id, deletePhotos);

  Future<bool> setActiveProject(String? id) => _platform.setActiveProject(id);

  Future<Map<String, dynamic>?> getActiveProject() =>
      _platform.getActiveProject();

  // ── Transport ──────────────────────────────────────────────────────────

  Future<String?> getTransportType() => _platform.getTransportType();

  Future<int?> getBatteryLevel() => _platform.getBatteryLevel();

  Future<Map<String, dynamic>?> getStorageInfo() => _platform.getStorageInfo();

  Future<Map<String, dynamic>?> getSessionDiagnostics() async {
    if (_platform is CameraMethodChannel) {
      return _platform.getSessionDiagnostics();
    }
    return null;
  }

  Future<String?> connectWifi(String host) async {
    if (_platform is CameraMethodChannel) {
      return _platform.connectWifi(host);
    }
    return null;
  }

  /// Connect preferring a specific transport ('USB' or 'WIFI').
  Future<String?> connectWithTransport(String transportType) async {
    if (_platform is CameraMethodChannel) {
      return _platform.connectWithTransport(transportType);
    }
    return null;
  }

  Future<Map<String, dynamic>?> scanCamera() async {
    // Only CameraMethodChannel supports scanning; _DefaultCameraPlatform doesn't
    if (_platform is CameraMethodChannel) {
      return _platform.scanCamera();
    }
    return null;
  }
}
