import 'package:freezed_annotation/freezed_annotation.dart';

part 'photo_item.freezed.dart';
part 'photo_item.g.dart';

@freezed
class PhotoItem with _$PhotoItem {
  const factory PhotoItem({
    /// Camera object handle (PTP).
    required int objectHandle,

    /// Original file name on the camera.
    required String fileName,

    /// Compressed file size in bytes.
    required int sizeBytes,

    /// Capture timestamp from EXIF (or file modification time).
    required DateTime captureDate,

    /// Local file path after sync (null if not yet downloaded).
    String? localPath,

    /// Path to a local thumbnail (null if not yet generated).
    String? thumbnailPath,

    /// Format code (0x3801 = EXIF JPEG).
    @Default(0x3801) int formatCode,

    /// Whether this photo has been synced to the phone.
    @Default(false) bool isSynced,
  }) = _PhotoItem;

  factory PhotoItem.fromJson(Map<String, dynamic> json) =>
      _$PhotoItemFromJson(json);
}

extension PhotoItemExt on PhotoItem {
  /// Detect NEF raw files by extension — avoids needing build_runner.
  bool get isRaw => fileName.toUpperCase().endsWith('.NEF');
}
