/// App-wide constants.
class AppConstants {
  AppConstants._();

  /// Nikon USB vendor ID (0x04B0).
  static const int nikonVendorId = 0x04B0;

  /// Thumbnail size for gallery grids (logical pixels).
  static const double thumbnailSize = 120.0;

  /// Maximum number of event-log entries kept in memory.
  static const int maxEventLogEntries = 200;

  /// Longest edge (px) for decoded preview bitmaps.
  static const int maxPreviewDimension = 2048;

  /// Platform channel name — must match the Kotlin side exactly.
  static const String platformChannelName = 'com.cacl2.ztransfer/camera';
}
