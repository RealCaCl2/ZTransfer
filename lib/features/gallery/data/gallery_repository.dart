import 'dart:async';
import 'package:ztransfer/features/gallery/data/models/photo_item.dart';
import 'package:ztransfer/platform/camera_platform_interface.dart';

/// Repository that mediates between the UI and the native PTP layer for
/// photo listing, download, and local storage operations.
class GalleryRepository {
  final CameraPlatform _platform;

  GalleryRepository({CameraPlatform? platform})
      : _platform = platform ?? CameraPlatform.instance;

  /// Broadcast stream of PTP events from the native layer.
  Stream<CameraEvent> get eventStream => _platform.eventStream;

  /// List JPEGs on the camera, converted to [PhotoItem] objects.
  Future<List<PhotoItem>> listCameraPhotos() async {
    final raw = await _platform.listCameraPhotos();
    return raw.map((m) => _mapToPhotoItem(m)).toList();
  }

  /// List locally-synced JPEGs, optionally scoped to a project.
  Future<List<PhotoItem>> listLocalPhotos({String? projectId}) async {
    final raw = await _platform.listLocalPhotos(projectId: projectId);
    return raw.map((m) => _mapToPhotoItem(m)).toList();
  }

  /// Download a single photo. Returns its local path on success.
  Future<String?> downloadPhoto(int objectHandle) {
    return _platform.downloadPhoto(objectHandle);
  }

  /// Delete a local photo file.
  Future<bool> deleteLocalPhoto(String filePath) {
    return _platform.deleteLocalPhoto(filePath);
  }

  /// Delete multiple local photos.
  Future<int> deleteMultiplePhotos(List<String> filePaths) {
    return _platform.deleteMultiplePhotos(filePaths);
  }

  /// Retrieve EXIF metadata for a local photo file.
  Future<Map<String, dynamic>?> getExifData(String filePath) {
    return _platform.getExifData(filePath);
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  PhotoItem _mapToPhotoItem(Map<String, dynamic> map) {
    return PhotoItem(
      objectHandle: (map['objectHandle'] as num?)?.toInt() ?? 0,
      fileName: map['fileName'] as String? ?? 'unknown',
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      captureDate: DateTime.tryParse(map['captureDate'] as String? ?? '') ??
          DateTime.now(),
      localPath: map['localPath'] as String?,
      formatCode: (map['formatCode'] as num?)?.toInt() ?? 0x3801,
      isSynced: map['isSynced'] as bool? ?? false,
    );
  }
}
