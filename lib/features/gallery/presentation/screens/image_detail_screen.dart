import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ztransfer/core/theme/app_colors.dart';
import 'package:ztransfer/features/camera/data/camera_repository.dart';
import 'package:ztransfer/features/camera/presentation/camera_notifier.dart';
import 'package:ztransfer/features/gallery/data/models/photo_item.dart';
import 'package:ztransfer/l10n/generated/app_localizations.dart';

/// Full-screen image viewer with swipe, pinch-to-zoom, and EXIF overlay.
///
/// Receives a list of [PhotoItem]s and an initial index so the user can
/// swipe left/right through the gallery.
class ImageDetailScreen extends ConsumerStatefulWidget {
  final List<PhotoItem> photos;
  final int initialIndex;

  const ImageDetailScreen({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  @override
  ConsumerState<ImageDetailScreen> createState() => _ImageDetailScreenState();
}

class _ImageDetailScreenState extends ConsumerState<ImageDetailScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _showOverlay = true;
  Map<String, String>? _exifData;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _loadExif();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadExif() async {
    final photo = widget.photos[_currentIndex];
    if (photo.localPath == null) return;
    try {
      final repo = ref.read(cameraRepositoryProvider);
      final data = await repo.getExifData(photo.localPath!);
      if (mounted) setState(() => _exifData = data?.cast<String, String>());
    } catch (_) {}
  }

  void _toggleOverlay() => setState(() => _showOverlay = !_showOverlay);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── PageView with pinch-to-zoom ──
          PageView.builder(
            controller: _pageController,
            itemCount: widget.photos.length,
            onPageChanged: (i) {
              _currentIndex = i;
              _exifData = null;
              _loadExif();
            },
            itemBuilder: (context, index) {
              final photo = widget.photos[index];
              return GestureDetector(
                onTap: _toggleOverlay,
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5.0,
                  child: Center(
                    child: photo.localPath != null
                        ? Hero(
                            tag: 'photo_${photo.objectHandle}',
                            child: Image.file(
                                File(photo.localPath!),
                                fit: BoxFit.contain),
                          )
                        : const Icon(Icons.broken_image,
                            size: 64, color: AppColors.textTertiary),
                  ),
                ),
              );
            },
          ),

          // ── Top bar ──
          if (_showOverlay)
            SafeArea(
              child: Container(
                color: Colors.black54,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        widget.photos[_currentIndex].fileName,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context)!.pageCounter(
                        _currentIndex + 1,
                        widget.photos.length,
                      ),
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.white, size: 22),
                      onPressed: () {
                        final photo = widget.photos[_currentIndex];
                        if (photo.localPath != null) {
                          CameraRepository()
                              .shareFile(photo.localPath!);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

          // ── EXIF sheet ──
          if (_showOverlay && _exifData != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _ExifPanel(data: _exifData!),
            ),
        ],
      ),
    );
  }
}

class _ExifPanel extends StatelessWidget {
  final Map<String, String> data;
  const _ExifPanel({required this.data});

  /// Convert exposure time to a fraction string (e.g., "0.008" → "1/125").
  static String _formatShutter(String value, String suffix) {
    if (value.contains('/')) return '$value$suffix';
    final d = double.tryParse(value);
    if (d == null || d <= 0) return '$value$suffix';
    if (d >= 1) return '${d.toStringAsFixed(1)}$suffix';
    final denominator = (1.0 / d).round();
    return '1/$denominator$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shutterSuffix = l10n.exifShutterSuffix;
    final items = <String, String>{
      if (data['iso']?.isNotEmpty == true) l10n.exifIso: data['iso']!,
      if (data['shutterSpeed']?.isNotEmpty == true)
        l10n.exifShutter: _formatShutter(data['shutterSpeed']!, shutterSuffix),
      if (data['aperture']?.isNotEmpty == true)
        l10n.exifAperture: l10n.exifFNumberPrefix(data['aperture']!),
      if (data['focalLength']?.isNotEmpty == true)
        l10n.exifFocal: l10n.exifFocalSuffix(data['focalLength']!),
      if (data['cameraModel']?.isNotEmpty == true) l10n.exifBody: data['cameraModel']!,
      if (data['dateTaken']?.isNotEmpty == true) l10n.exifDate: data['dateTaken']!,
    };

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 8,
        children: items.entries.map((e) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(e.value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              Text(e.key,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 11)),
            ],
          );
        }).toList(),
      ),
    );
  }
}
