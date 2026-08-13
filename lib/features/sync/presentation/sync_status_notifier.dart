import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ztransfer/core/logger/app_logger.dart';
import 'package:ztransfer/features/gallery/data/models/photo_item.dart';
import 'package:ztransfer/features/gallery/presentation/gallery_notifier.dart';
import 'package:ztransfer/features/project/presentation/project_notifier.dart';
import 'package:ztransfer/platform/camera_method_channel.dart';
import 'package:ztransfer/platform/camera_platform_interface.dart';

part 'sync_status_notifier.g.dart';

enum SyncStatus {
  idle,
  syncing,
  error,
}

class SyncState {
  final SyncStatus status;
  final int totalSynced;
  final int? currentObjectHandle;
  final String? errorMessage;
  final PhotoItem? lastSyncedPhoto;
  final bool isListening;
  final double transferProgress;
  final double transferRateBytesPerSecond;
  final int bytesTransferred;
  final int totalBytes;

  /// Whether newly-imported photos should automatically open full-screen.
  final bool autoShowEnabled;

  const SyncState({
    this.status = SyncStatus.idle,
    this.totalSynced = 0,
    this.currentObjectHandle,
    this.errorMessage,
    this.lastSyncedPhoto,
    this.isListening = false,
    this.transferProgress = 0,
    this.transferRateBytesPerSecond = 0,
    this.bytesTransferred = 0,
    this.totalBytes = 0,
    this.autoShowEnabled = true,
  });

  SyncState copyWith({
    SyncStatus? status,
    int? totalSynced,
    int? currentObjectHandle,
    String? errorMessage,
    PhotoItem? lastSyncedPhoto,
    bool? isListening,
    double? transferProgress,
    double? transferRateBytesPerSecond,
    int? bytesTransferred,
    int? totalBytes,
    bool? autoShowEnabled,
    bool clearCurrentObjectHandle = false,
    bool clearLastSyncedPhoto = false,
    bool clearTransferMetrics = false,
  }) {
    return SyncState(
      status: status ?? this.status,
      totalSynced: totalSynced ?? this.totalSynced,
      currentObjectHandle: clearCurrentObjectHandle
          ? null
          : currentObjectHandle ?? this.currentObjectHandle,
      errorMessage: errorMessage,
      lastSyncedPhoto:
          clearLastSyncedPhoto ? null : lastSyncedPhoto ?? this.lastSyncedPhoto,
      isListening: isListening ?? this.isListening,
      transferProgress:
          clearTransferMetrics ? 0 : transferProgress ?? this.transferProgress,
      transferRateBytesPerSecond: clearTransferMetrics
          ? 0
          : transferRateBytesPerSecond ?? this.transferRateBytesPerSecond,
      bytesTransferred:
          clearTransferMetrics ? 0 : bytesTransferred ?? this.bytesTransferred,
      totalBytes: clearTransferMetrics ? 0 : totalBytes ?? this.totalBytes,
      autoShowEnabled: autoShowEnabled ?? this.autoShowEnabled,
    );
  }
}

/// ──────────────────────────────────────────────────────────────────────────────
/// Watches the native event stream for [ObjectAddedEvent] and orchestrates
/// the "shoot → download → display" pipeline.
///
/// This is the Flutter-side counterpart of the native PtpManager event loop.
/// It does NOT re-implement PTP — it only reacts to events the native layer
/// pushes up.
/// ──────────────────────────────────────────────────────────────────────────────
@riverpod
class SyncNotifier extends _$SyncNotifier {
  StreamSubscription<CameraEvent>? _eventSub;
  Timer? _statusDismissTimer;
  bool _disposed = false;

  static const _successStatusDuration = Duration(seconds: 4);
  static const _errorStatusDuration = Duration(seconds: 6);

  @override
  SyncState build() {
    _disposed = false;
    _listenToEvents();
    ref.onDispose(() {
      _disposed = true;
      _eventSub?.cancel();
      _statusDismissTimer?.cancel();
    });
    Future<void>.microtask(_restoreTransferState);
    return const SyncState();
  }

  void _listenToEvents() {
    appLogger.d('SyncNotifier: subscribing to event stream');
    final repo = ref.read(galleryRepositoryProvider);
    _eventSub = repo.eventStream.listen((event) {
      appLogger.d('SyncNotifier: received ${event.runtimeType}');
      if (event is ObjectAddedEvent) {
        appLogger.i(
          'ObjectAdded: handle=${event.objectHandle} '
          'path=${event.localPath} size=${event.sizeBytes}',
        );
        _onObjectAdded(event);
      } else if (event is ObjectRemovedEvent) {
        appLogger.i('ObjectRemoved: handle=${event.objectHandle}');
        _onObjectRemoved(event);
      } else if (event is TransferProgressEvent) {
        _cancelStatusDismiss();
        state = state.copyWith(
          status: SyncStatus.syncing,
          isListening: true,
          currentObjectHandle: event.objectHandle,
          transferProgress: event.progress,
          transferRateBytesPerSecond: event.bytesPerSecond,
          bytesTransferred: event.bytesTransferred,
          totalBytes: event.totalBytes,
          errorMessage: null,
          clearLastSyncedPhoto: true,
        );
      } else if (event is TransferStateChangedEvent) {
        state = state.copyWith(
          status: state.status == SyncStatus.error
              ? SyncStatus.error
              : SyncStatus.idle,
          isListening: event.listening,
          clearCurrentObjectHandle: true,
          clearTransferMetrics: true,
        );
        if (!event.listening) {
          unawaited(
            ref.read(galleryNotifierProvider.notifier).refreshLocalPhotos(),
          );
        }
      } else if (event is ConnectionStateChangedEvent && !event.connected) {
        state = state.copyWith(
          isListening: false,
          clearCurrentObjectHandle: true,
          clearTransferMetrics: true,
        );
      } else if (event is LogEvent &&
          event.level.toUpperCase() == 'ERROR' &&
          state.isListening &&
          _isTransferMessage(event.message)) {
        state = state.copyWith(
          status: SyncStatus.error,
          errorMessage: event.message,
          clearCurrentObjectHandle: true,
        );
        // The working copy may already be complete even if a later native operation failed.
        unawaited(
          ref.read(galleryNotifierProvider.notifier).refreshLocalPhotos(),
        );
        _scheduleErrorDismiss();
      }
    });
  }

  Future<void> _onObjectAdded(ObjectAddedEvent event) async {
    final localPath = event.localPath;
    if (localPath == null || localPath.isEmpty) {
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: 'ObjectAdded missing localPath',
        clearCurrentObjectHandle: true,
      );
      _scheduleErrorDismiss();
      return;
    }

    _cancelStatusDismiss();
    state = state.copyWith(
      status: SyncStatus.syncing,
      currentObjectHandle: event.objectHandle,
      clearLastSyncedPhoto: true,
    );

    try {
      // The native PtpManager already downloaded and saved the JPEG.
      // event.localPath points to the saved file — no second download needed.
      final photo = PhotoItem(
        objectHandle: event.objectHandle,
        fileName: event.fileName,
        sizeBytes: event.sizeBytes,
        captureDate: DateTime.now(),
        localPath: localPath,
        formatCode: event.formatCode,
        isSynced: true,
      );

      // Add to the local gallery immediately
      appLogger.i('SyncNotifier: adding synced photo to gallery');
      ref.read(galleryNotifierProvider.notifier).addSyncedPhoto(photo);
      state = state.copyWith(
        status: SyncStatus.idle,
        totalSynced: state.totalSynced + 1,
        lastSyncedPhoto: photo,
        errorMessage: null,
        clearCurrentObjectHandle: true,
      );
      _scheduleSuccessDismiss();

      // Metadata refresh is secondary. It must not turn an already-visible completed photo into
      // a sync failure.
      if (ref.read(projectNotifierProvider).activeProject != null) {
        try {
          await ref.read(projectNotifierProvider.notifier).refresh();
        } catch (e, st) {
          appLogger.w(
            'Project metadata refresh failed after sync',
            error: e,
            stackTrace: st,
          );
        }
      }
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      );
      _scheduleErrorDismiss();
    }
  }

  Future<void> _restoreTransferState() async {
    final snapshot = await CameraMethodChannel().getTransferStatus();
    if (_disposed || snapshot == null) return;
    final listening = snapshot['listening'] == true;
    state = state.copyWith(
      isListening: listening,
      transferProgress: (snapshot['progress'] as num?)?.toDouble() ?? 0,
      transferRateBytesPerSecond:
          (snapshot['bytesPerSecond'] as num?)?.toDouble() ?? 0,
      bytesTransferred: (snapshot['bytesTransferred'] as num?)?.toInt() ?? 0,
      totalBytes: (snapshot['totalBytes'] as num?)?.toInt() ?? 0,
      clearTransferMetrics: !listening,
    );
  }

  Future<String?> startListening() async {
    _cancelStatusDismiss();
    final result = await CameraMethodChannel().startTransfer();
    if (_disposed) return null;
    final status = result?['status'] as String?;
    if (status == 'started' || status == 'already_running') {
      state = state.copyWith(
        status: SyncStatus.idle,
        isListening: true,
        errorMessage: null,
        clearLastSyncedPhoto: true,
        clearTransferMetrics: status == 'started',
      );
    }
    return status;
  }

  Future<String?> stopListening() async {
    final status = await CameraMethodChannel().stopTransfer();
    if (_disposed) return null;
    if (status == 'stopped' || status == 'not_running') {
      state = state.copyWith(
        status: SyncStatus.idle,
        isListening: false,
        clearCurrentObjectHandle: true,
        clearTransferMetrics: true,
      );
    }
    return status;
  }

  void _onObjectRemoved(ObjectRemovedEvent event) {
    // Remove from the gallery if it was synced
    ref
        .read(galleryNotifierProvider.notifier)
        .removeSyncedPhotoByHandle(event.objectHandle);
  }

  bool _isTransferMessage(String message) {
    return message.contains('传输') ||
        message.contains('下载') ||
        message.contains('无线') ||
        message.contains('AdvancedTransfer') ||
        message.contains('GetPartialObject');
  }

  /// Toggle automatic full-screen display of newly-imported photos.
  void toggleAutoShow() {
    state = state.copyWith(autoShowEnabled: !state.autoShowEnabled);
  }

  /// Clear the "last synced" highlight after the user has seen it.
  void acknowledgeLastSync() {
    _cancelStatusDismiss();
    state = state.copyWith(clearLastSyncedPhoto: true);
  }

  /// Reset error state — allows the user to retry after a failure.
  void clearError() {
    _cancelStatusDismiss();
    state = state.copyWith(
      status: SyncStatus.idle,
      errorMessage: null,
      clearLastSyncedPhoto: true,
    );
  }

  void _cancelStatusDismiss() {
    _statusDismissTimer?.cancel();
    _statusDismissTimer = null;
  }

  void _scheduleSuccessDismiss() {
    _cancelStatusDismiss();
    _statusDismissTimer = Timer(_successStatusDuration, () {
      _statusDismissTimer = null;
      if (_disposed || state.status != SyncStatus.idle) return;
      state = state.copyWith(clearLastSyncedPhoto: true);
    });
  }

  void _scheduleErrorDismiss() {
    _cancelStatusDismiss();
    _statusDismissTimer = Timer(_errorStatusDuration, () {
      _statusDismissTimer = null;
      if (_disposed || state.status != SyncStatus.error) return;
      state = state.copyWith(
        status: SyncStatus.idle,
        errorMessage: null,
        clearLastSyncedPhoto: true,
      );
    });
  }
}
