import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:ztransfer/app_router.dart';
import 'package:ztransfer/core/theme/app_colors.dart';
import 'package:ztransfer/features/camera/data/camera_repository.dart';
import 'package:ztransfer/features/gallery/data/models/photo_item.dart';
import 'package:ztransfer/features/gallery/presentation/gallery_notifier.dart';
import 'package:ztransfer/features/project/presentation/project_notifier.dart';
import 'package:ztransfer/l10n/generated/app_localizations.dart';

/// Phone gallery with multi-select batch operations.
///
/// Normal mode: tap → detail, long-press → enter selection mode.
/// Selection mode: checkboxes, batch delete & share.
class PhoneGalleryScreen extends ConsumerStatefulWidget {
  const PhoneGalleryScreen({super.key});

  @override
  ConsumerState<PhoneGalleryScreen> createState() =>
      _PhoneGalleryScreenState();
}

class _PhoneGalleryScreenState extends ConsumerState<PhoneGalleryScreen> {
  final Set<String> _selected = {}; // keys are localPath
  bool _selecting = false;

  void _enterSelection(String key) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selecting = true;
      _selected.add(key);
    });
  }

  void _exitSelection() {
    setState(() {
      _selecting = false;
      _selected.clear();
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

  Future<void> _deleteSelected() async {
    final count = _selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteConfirmTitle(count)),
        content:
            Text(AppLocalizations.of(context)!.deleteConfirmMessage),
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
    final repo = ref.read(galleryRepositoryProvider);
    await repo.deleteMultiplePhotos(paths);
    ref.read(galleryNotifierProvider.notifier).refreshLocalPhotos();
    ref.read(projectNotifierProvider.notifier).refresh();
    _exitSelection();
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
    final state = ref.watch(galleryNotifierProvider);
    final photos = state.localPhotos;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _selecting
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelection,
              ),
              title: Text(AppLocalizations.of(context)!.selectedCount(_selected.length)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed:
                      _selected.isNotEmpty ? _shareSelected : null,
                ),
                IconButton(
                  icon: const Icon(Icons.delete,
                      color: AppColors.statusError),
                  onPressed:
                      _selected.isNotEmpty ? _deleteSelected : null,
                ),
              ],
            )
          : AppBar(
              title: Text(AppLocalizations.of(context)!.phoneGallery),
            ),
      body: photos.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_library_outlined,
                      size: 48, color: AppColors.textTertiary),
                  const SizedBox(height: 12),
                  Text(AppLocalizations.of(context)!.emptyNoSyncedPhotos,
                      style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(4),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 4 / 3,
              ),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                final photo = photos[index];
                final key = photo.localPath ?? '';
                final isSelected = _selected.contains(key);
                return _GridTile(
                  photo: photo,
                  selecting: _selecting,
                  isSelected: isSelected,
                  onTap: () {
                    if (_selecting) {
                      _toggleSelection(key);
                    } else {
                      context.push(
                        AppRoute.detailPath(photo.objectHandle),
                        extra: photos,
                      );
                    }
                  },
                  onLongPress: () {
                    if (!_selecting) {
                      _enterSelection(key);
                    }
                  },
                );
              },
            ),
    );
  }
}

class _GridTile extends StatelessWidget {
  final PhotoItem photo;
  final bool selecting;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _GridTile({
    required this.photo,
    required this.selecting,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: isSelected
                  ? Border.all(color: AppColors.accent, width: 2.5)
                  : null,
            ),
            child: photo.localPath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(
                      File(photo.localPath!),
                      fit: BoxFit.cover,
                      cacheWidth: 300,
                      errorBuilder: (_, __, ___) =>
                          _Placeholder(photo: photo),
                    ),
                  )
                : _Placeholder(photo: photo),
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
                  color: isSelected
                      ? AppColors.accent
                      : Colors.black45,
                  border: Border.all(
                      color: Colors.white, width: 2),
                ),
                child: isSelected
                    ? const Icon(Icons.check,
                        size: 14, color: Colors.black)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final PhotoItem photo;
  const _Placeholder({required this.photo});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.image_outlined,
              color: AppColors.textTertiary, size: 28),
          Text(photo.fileName,
              style: const TextStyle(
                  color: AppColors.textTertiary, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
