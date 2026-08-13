import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ztransfer/features/gallery/data/gallery_repository.dart';
import 'package:ztransfer/features/gallery/data/models/photo_item.dart';
import 'package:ztransfer/features/project/presentation/project_notifier.dart';
import 'package:ztransfer/platform/camera_platform_interface.dart';

/// State for the gallery.
class GalleryState {
  final List<PhotoItem> localPhotos;
  final bool isLoading;

  const GalleryState({
    this.localPhotos = const [],
    this.isLoading = false,
  });

  GalleryState copyWith({
    List<PhotoItem>? localPhotos,
    bool? isLoading,
  }) {
    return GalleryState(
      localPhotos: localPhotos ?? this.localPhotos,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Manages the photo gallery, scoped to the active project.
///
/// Uses a plain [StateNotifier] rather than @riverpod to avoid
/// build()-lifecycle issues with async initialisation.
class GalleryNotifier extends StateNotifier<GalleryState> {
  final Ref _ref;
  StreamSubscription<CameraEvent>? _eventSub;
  int _loadRevision = 0;

  GalleryNotifier(this._ref) : super(const GalleryState()) {
    _init();
  }

  void _init() {
    // Reload when active project changes
    _ref.listen<ProjectState?>(
      projectNotifierProvider,
      (prev, next) {
        if (prev?.activeProject?.id != next?.activeProject?.id) {
          debugPrint('Gallery: project changed, reloading');
          _loadLocalPhotos();
        }
      },
    );
    _listenToEvents();
    _loadLocalPhotos();
  }

  Future<void> _loadLocalPhotos() async {
    final revision = ++_loadRevision;
    state = state.copyWith(isLoading: true);
    final repo = GalleryRepository();
    final projectId = _ref.read(projectNotifierProvider).activeProject?.id;
    debugPrint('Gallery._loadLocalPhotos: projectId=$projectId');
    try {
      final photos = await repo.listLocalPhotos(projectId: projectId);
      debugPrint('Gallery._loadLocalPhotos: loaded ${photos.length} photos');
      if (revision != _loadRevision ||
          _ref.read(projectNotifierProvider).activeProject?.id != projectId) {
        return;
      }
      state = state.copyWith(localPhotos: photos, isLoading: false);
    } catch (e) {
      debugPrint('Gallery._loadLocalPhotos error: $e');
      if (revision == _loadRevision) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  void addSyncedPhoto(PhotoItem photo) {
    // A query started before this event must not overwrite the newly inserted photo.
    _loadRevision++;
    final withoutDuplicate = state.localPhotos.where((existing) {
      if (photo.localPath != null && existing.localPath == photo.localPath) {
        return false;
      }
      return existing.objectHandle != photo.objectHandle;
    }).toList();
    state = state.copyWith(
      localPhotos: [photo, ...withoutDuplicate],
      isLoading: false,
    );
  }

  /// Remove a photo from the gallery by its object handle.
  /// Called when the camera sends ObjectRemoved.
  void removeSyncedPhotoByHandle(int objectHandle) {
    state = state.copyWith(
      localPhotos: state.localPhotos
          .where((p) => p.objectHandle != objectHandle)
          .toList(),
    );
  }

  Future<void> refreshLocalPhotos() => _loadLocalPhotos();

  Future<bool> deleteLocalPhoto(String filePath) async {
    final repo = GalleryRepository();
    final ok = await repo.deleteLocalPhoto(filePath);
    if (ok) {
      state = state.copyWith(
        localPhotos:
            state.localPhotos.where((p) => p.localPath != filePath).toList(),
      );
    }
    return ok;
  }

  void _listenToEvents() {
    final repo = GalleryRepository();
    _eventSub?.cancel();
    _eventSub = repo.eventStream.listen((event) {
      if (event is ObjectAddedEvent &&
          event.localPath != null &&
          event.localPath!.isNotEmpty) {
        addSyncedPhoto(
          PhotoItem(
            objectHandle: event.objectHandle,
            fileName: event.fileName,
            sizeBytes: event.sizeBytes,
            captureDate: DateTime.now(),
            localPath: event.localPath,
            formatCode: event.formatCode,
            isSynced: true,
          ),
        );
      } else if (event is ObjectRemovedEvent) {
        removeSyncedPhotoByHandle(event.objectHandle);
      } else if (event is ConnectionStateChangedEvent) {
        // Camera disconnected — keep showing local photos
      }
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }
}

final galleryNotifierProvider =
    StateNotifierProvider<GalleryNotifier, GalleryState>((ref) {
  return GalleryNotifier(ref);
});

/// Shared repository instance — used by SyncNotifier.
final galleryRepositoryProvider = Provider<GalleryRepository>((ref) {
  return GalleryRepository();
});
