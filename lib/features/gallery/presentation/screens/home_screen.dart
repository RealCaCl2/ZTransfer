import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:ztransfer/app_router.dart';
import 'package:ztransfer/core/theme/app_colors.dart';
import 'package:ztransfer/features/camera/data/camera_repository.dart';
import 'package:ztransfer/features/camera/presentation/camera_notifier.dart';
import 'package:ztransfer/features/camera/presentation/widgets/camera_status_card.dart';
import 'package:ztransfer/features/gallery/data/models/photo_item.dart';
import 'package:ztransfer/features/gallery/presentation/gallery_notifier.dart';
import 'package:ztransfer/features/project/presentation/project_notifier.dart';
import 'package:ztransfer/core/widgets/shimmer_loading.dart';
import 'package:ztransfer/features/sync/presentation/sync_status_notifier.dart';
import 'package:ztransfer/l10n/generated/app_localizations.dart';

/// ──────────────────────────────────────────────────────────────────────────────
/// Home screen — the default route.
///
/// Layout (top → bottom):
///   1. Camera status card (connection state + connect/retry CTA)
///   2. Camera gallery grid (JPEGs on the camera)
///   3. Sync status bar (idle / syncing / last-synced highlight)
/// ──────────────────────────────────────────────────────────────────────────────
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final Set<String> _selected = {};
  bool _selecting = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _enterSelection(String key) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selecting = true;
      _selected.add(key);
    });
  }

  void _toggleSelection(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected.contains(key)) {
        _selected.remove(key);
        if (_selected.isEmpty) _selecting = false;
      } else {
        _selected.add(key);
      }
    });
  }

  void _exitSelection() => setState(() {
        _selecting = false;
        _selected.clear();
      });

  Future<void> _deleteSelected() async {
    final count = _selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteConfirmTitle(count)),
        content: Text(AppLocalizations.of(context)!.deleteConfirmMessage),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalizations.of(context)!.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppLocalizations.of(context)!.delete,
                  style: const TextStyle(color: AppColors.statusError))),
        ],
      ),
    );
    if (confirmed != true) return;
    final paths = _selected.toList();
    _exitSelection();
    final repo = ref.read(galleryRepositoryProvider);
    await repo.deleteMultiplePhotos(paths);
    ref.read(galleryNotifierProvider.notifier).refreshLocalPhotos();
    ref.read(projectNotifierProvider.notifier).refresh();
  }

  void _shareSelected() {
    final paths = _selected.toList();
    _exitSelection();
    final repo = CameraRepository();
    if (paths.length == 1) {
      repo.shareFile(paths.first);
    } else {
      repo.shareMultipleFiles(paths);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraNotifierProvider);
    final galleryState = ref.watch(galleryNotifierProvider);
    final syncState = ref.watch(syncNotifierProvider);

    // ── Auto-show: navigate to full-screen when a new photo is imported ──
    ref.listen<SyncState>(syncNotifierProvider, (prev, next) {
      if (!mounted || _selecting) return;
      if (!next.autoShowEnabled) return;
      final prevHandle = prev?.lastSyncedPhoto?.objectHandle;
      final nextHandle = next.lastSyncedPhoto?.objectHandle;
      if (nextHandle != null && nextHandle != prevHandle) {
        final photos = ref.read(galleryNotifierProvider).localPhotos;
        final detailPath = AppRoute.detailPath(nextHandle);
        // Use GoRouter.state (sync from delegate) rather than
        // GoRouterState.of(context) (async via InheritedWidget rebuild)
        // so rapid sequential shots don't stack multiple detail routes.
        final currentLocation = GoRouter.of(context).state.uri.toString();
        if (currentLocation.startsWith('/detail/')) {
          GoRouter.of(context).replace(detailPath, extra: photos);
        } else {
          context.push(detailPath, extra: photos);
        }
      }
    });

    return Scaffold(
      bottomNavigationBar: _selecting
          ? SafeArea(
              child: Container(
                color: AppColors.surface,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _exitSelection,
                      child: Text(AppLocalizations.of(context)!.cancel,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 14)),
                    ),
                    const Spacer(),
                    Text(
                        AppLocalizations.of(context)!
                            .selectedCount(_selected.length),
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 14)),
                    const Spacer(),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.share,
                              color: AppColors.accent, size: 22),
                          onPressed:
                              _selected.isNotEmpty ? _shareSelected : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              color: AppColors.statusError, size: 22),
                          onPressed:
                              _selected.isNotEmpty ? _deleteSelected : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Text(
                    AppLocalizations.of(context)!.appTitle,
                    style: Theme.of(context)
                        .textTheme
                        .headlineLarge
                        ?.copyWith(color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  PopupMenuButton<_HomeHeaderAction>(
                    icon: const Icon(
                      Icons.help_outline_rounded,
                      color: AppColors.textSecondary,
                      size: 22,
                    ),
                    tooltip: AppLocalizations.of(context).tutorialTitle,
                    onSelected: (action) {
                      switch (action) {
                        case _HomeHeaderAction.tutorial:
                          context.push(AppRoute.tutorial);
                        case _HomeHeaderAction.about:
                          context.push(AppRoute.about);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: _HomeHeaderAction.tutorial,
                        child: Row(
                          children: [
                            const Icon(Icons.menu_book_outlined, size: 20),
                            const SizedBox(width: 12),
                            Text(AppLocalizations.of(context).tutorialTitle),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: _HomeHeaderAction.about,
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 20),
                            const SizedBox(width: 12),
                            Text(AppLocalizations.of(context).aboutTitle),
                          ],
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.folder_outlined,
                        color: AppColors.textSecondary),
                    onPressed: () => context.push(AppRoute.projects),
                  ),
                ],
              ),
            ),
            // Active project indicator
            Builder(builder: (context) {
              final projectState = ref.watch(projectNotifierProvider);
              final active = projectState.activeProject;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () => context.push(AppRoute.projects),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder,
                            size: 16,
                            color: active != null
                                ? AppColors.accent
                                : AppColors.statusError),
                        const SizedBox(width: 6),
                        Text(
                          active?.name ??
                              AppLocalizations.of(context)!.noProjectSelected,
                          style: TextStyle(
                            color: active != null
                                ? AppColors.textPrimary
                                : AppColors.statusError,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right,
                            size: 16, color: AppColors.textTertiary),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),

            // ── Camera status ──────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: CameraStatusCard(),
            ),
            const SizedBox(height: 16),

            // ── Section: Photos ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    AppLocalizations.of(context)!.photos,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  _AutoShowToggle(
                    enabled: syncState.autoShowEnabled,
                    onPressed: () => ref
                        .read(syncNotifierProvider.notifier)
                        .toggleAutoShow(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── Unified photo grid ─────────────────────────────────────────
            Expanded(
              child: galleryState.isLoading
                  ? const ShimmerGrid()
                  : galleryState.localPhotos.isEmpty
                      ? _EmptyPlaceholder(
                          message: cameraState.isConnected
                              ? AppLocalizations.of(context)!.emptyNoPhotos
                              : AppLocalizations.of(context)!
                                  .emptyConnectPrompt,
                        )
                      : RefreshIndicator(
                          color: AppColors.accent,
                          onRefresh: () => ref
                              .read(galleryNotifierProvider.notifier)
                              .refreshLocalPhotos(),
                          child: _PhotoGrid(
                            photos: galleryState.localPhotos,
                            scrollController: _scrollController,
                            highlightHandle:
                                syncState.lastSyncedPhoto?.objectHandle,
                            selecting: _selecting,
                            selectedKeys: _selected,
                            onTap: (photo) {
                              if (_selecting) {
                                _toggleSelection(photo.localPath ?? '');
                              } else {
                                context.push(
                                  AppRoute.detailPath(photo.objectHandle),
                                  extra: galleryState.localPhotos,
                                );
                              }
                            },
                            onLongPress: (photo) {
                              if (!_selecting) {
                                HapticFeedback.mediumImpact();
                                _enterSelection(photo.localPath ?? '');
                              }
                            },
                          ),
                        ),
            ),

            // ── Sync status bar ────────────────────────────────────────────
            _SyncStatusBar(syncState: syncState),
          ],
        ),
      ),
    );
  }
}

class _AutoShowToggle extends StatelessWidget {
  const _AutoShowToggle({
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = enabled ? l10n.autoShowOn : l10n.autoShowOff;
    final color = enabled ? AppColors.accent : AppColors.textSecondary;

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        toggled: enabled,
        label: label,
        child: Material(
          color: enabled
              ? AppColors.accent.withAlpha(22)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(9),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: enabled
                      ? AppColors.accent.withAlpha(105)
                      : AppColors.surfaceHighlight,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    enabled
                        ? Icons.fullscreen_rounded
                        : Icons.fullscreen_exit_rounded,
                    color: color,
                    size: 17,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _HomeHeaderAction { tutorial, about }

// ──────────────────────────────────────────────────────────────────────────────
// Photo grid
// ──────────────────────────────────────────────────────────────────────────────

class _PhotoGrid extends StatelessWidget {
  final List<PhotoItem> photos;
  final ScrollController scrollController;
  final int? highlightHandle;
  final bool selecting;
  final Set<String> selectedKeys;
  final void Function(PhotoItem) onTap;
  final void Function(PhotoItem) onLongPress;

  const _PhotoGrid({
    required this.photos,
    required this.scrollController,
    this.highlightHandle,
    this.selecting = false,
    this.selectedKeys = const {},
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 4 / 3,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        final isHighlighted = photo.objectHandle == highlightHandle;
        final key = photo.localPath ?? '';
        final isSelected = selectedKeys.contains(key);

        return GestureDetector(
          onTap: () => onTap(photo),
          onLongPress: () => onLongPress(photo),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: isSelected
                      ? Border.all(color: AppColors.accent, width: 2.5)
                      : isHighlighted
                          ? Border.all(color: AppColors.accent, width: 2)
                          : null,
                ),
                child: photo.localPath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Hero(
                          tag: 'photo_${photo.objectHandle}',
                          child: Image.file(
                            File(photo.localPath!),
                            fit: BoxFit.cover,
                            cacheWidth: 300,
                            errorBuilder: (_, __, ___) =>
                                _PhotoPlaceholder(fileName: photo.fileName),
                          ),
                        ),
                      )
                    : _PhotoPlaceholder(fileName: photo.fileName),
              ),
              // NEF raw badge
              if (!selecting && photo.isRaw)
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(AppLocalizations.of(context)!.rawBadge,
                        style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 9,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              if (selecting)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? AppColors.accent : Colors.black45,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 14, color: Colors.black)
                        : null,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  final String fileName;
  const _PhotoPlaceholder({required this.fileName});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceElevated,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.image_outlined,
              color: AppColors.textTertiary,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              fileName,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Empty state
// ──────────────────────────────────────────────────────────────────────────────

class _EmptyPlaceholder extends StatelessWidget {
  final String message;
  const _EmptyPlaceholder({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.photo_library_outlined,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Sync status bar
// ──────────────────────────────────────────────────────────────────────────────

class _SyncStatusBar extends ConsumerWidget {
  final SyncState syncState;
  const _SyncStatusBar({required this.syncState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (syncState.status == SyncStatus.idle &&
        syncState.lastSyncedPhoto == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.surface,
      child: syncState.status == SyncStatus.syncing
          ? Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.statusSyncing,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  AppLocalizations.of(context)!.syncing,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.statusSyncing),
                ),
              ],
            )
          : syncState.status == SyncStatus.error
              ? Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 16,
                      color: AppColors.statusError,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        syncState.errorMessage ??
                            AppLocalizations.of(context)!.syncError,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.statusError),
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          ref.read(syncNotifierProvider.notifier).clearError(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.statusError.withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(AppLocalizations.of(context)!.retry,
                            style: TextStyle(
                                color: AppColors.statusError,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: AppColors.statusConnected,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      AppLocalizations.of(context)!
                          .lastSync(syncState.lastSyncedPhoto?.fileName ?? ''),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.statusConnected),
                    ),
                  ],
                ),
    );
  }
}
