import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ztransfer/app_router.dart';
import 'package:ztransfer/core/theme/app_colors.dart';
import 'package:ztransfer/features/camera/presentation/camera_notifier.dart';
import 'package:ztransfer/features/camera/presentation/widgets/connection_dialog.dart';
import 'package:ztransfer/features/project/presentation/project_notifier.dart';
import 'package:ztransfer/features/sync/presentation/sync_status_notifier.dart';
import 'package:ztransfer/l10n/generated/app_localizations.dart';

/// Status card shown at the top of the home screen.
///
/// Reflects the current [CameraConnectionStatus] — disconnected, connecting,
/// connected, or error — with appropriate iconography and colour coding.
class CameraStatusCard extends ConsumerWidget {
  const CameraStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cameraState = ref.watch(cameraNotifierProvider);
    final syncState = ref.watch(syncNotifierProvider);
    final status = cameraState.status;

    return GestureDetector(
      onTap: () async {
        if (status == CameraConnectionStatus.disconnected ||
            status == CameraConnectionStatus.error) {
          await ref.read(projectNotifierProvider.notifier).refresh();
          if (!context.mounted) return;
          if (ref.read(projectNotifierProvider).projects.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context).syncNoProjectError,
                ),
              ),
            );
            context.push(AppRoute.projects);
            return;
          }
          showDialog(
            context: context,
            builder: (_) => const ConnectionDialog(),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: syncState.isListening
              ? Border.all(color: AppColors.accent.withAlpha(170), width: 1.5)
              : null,
          boxShadow: syncState.isListening
              ? [
                  BoxShadow(
                    color: AppColors.accent.withAlpha(20),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _StatusIcon(
                  status: status,
                  connectionType: cameraState.connectionType,
                ),
                const SizedBox(width: 12),
                Expanded(child: _StatusText(cameraState: cameraState)),
                if (cameraState.isConnected && cameraState.batteryLevel != null)
                  _BatteryIndicator(level: cameraState.batteryLevel!),
                if (cameraState.isConnected &&
                    cameraState.connectionType == ConnectionType.wifi)
                  _ReceiveButton(isListening: syncState.isListening),
                if (cameraState.isConnected) ...[
                  const SizedBox(width: 4),
                  const _DisconnectButton(),
                ],
                if (status == CameraConnectionStatus.disconnected ||
                    status == CameraConnectionStatus.error)
                  _ConnectPrompt(status: status),
              ],
            ),
            if (syncState.isListening) ...[
              const SizedBox(height: 12),
              _ListeningStatus(syncState: syncState),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final CameraConnectionStatus status;
  final ConnectionType connectionType;
  const _StatusIcon({
    required this.status,
    this.connectionType = ConnectionType.none,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      CameraConnectionStatus.connected => (
          Icons.camera_alt_rounded,
          AppColors.statusConnected,
        ),
      CameraConnectionStatus.connecting => (
          Icons.sync_rounded,
          AppColors.statusSyncing,
        ),
      CameraConnectionStatus.error => (
          Icons.error_outline_rounded,
          AppColors.statusError,
        ),
      CameraConnectionStatus.disconnected => (
          connectionType == ConnectionType.wifi
              ? Icons.wifi_rounded
              : Icons.usb_rounded,
          AppColors.statusDisconnected,
        ),
    };

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _StatusText extends StatelessWidget {
  final CameraState cameraState;
  const _StatusText({required this.cameraState});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final transportLabel = switch (cameraState.connectionType) {
      ConnectionType.usb => 'USB',
      ConnectionType.wifi => cameraState.ipAddress != null
          ? 'Wi-Fi · ${cameraState.ipAddress}'
          : 'Wi-Fi',
      ConnectionType.none => '',
    };

    final (title, subtitle) = switch (cameraState.status) {
      CameraConnectionStatus.connected => (
          cameraState.deviceName ?? l10n.cameraConnected,
          transportLabel.isNotEmpty
              ? '$transportLabel · ${l10n.cameraReady}'
              : l10n.cameraReady,
        ),
      CameraConnectionStatus.connecting => (
          l10n.cameraConnecting,
          l10n.cameraEstablishing,
        ),
      CameraConnectionStatus.error => (
          l10n.cameraError,
          cameraState.errorMessage ?? l10n.cameraUnknownError,
        ),
      CameraConnectionStatus.disconnected => (
          l10n.cameraNoCamera,
          l10n.cameraConnectPrompt,
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}

class _BatteryIndicator extends StatelessWidget {
  final int level;
  const _BatteryIndicator({required this.level});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            level > 80
                ? Icons.battery_full_rounded
                : level > 50
                    ? Icons.battery_5_bar_rounded
                    : level > 20
                        ? Icons.battery_3_bar_rounded
                        : Icons.battery_1_bar_rounded,
            color:
                level > 20 ? AppColors.statusConnected : AppColors.statusError,
            size: 18,
          ),
          const SizedBox(width: 2),
          Text(
            '$level%',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _ReceiveButton extends ConsumerWidget {
  final bool isListening;

  const _ReceiveButton({required this.isListening});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: () async {
        final notifier = ref.read(syncNotifierProvider.notifier);
        final status = isListening
            ? await notifier.stopListening()
            : await notifier.startListening();
        if (context.mounted) {
          final message = switch (status) {
            'started' => l10n.transferListeningStarted,
            'already_running' => l10n.transferAlreadyListening,
            'stopped' || 'not_running' => l10n.transferListeningStopped,
            _ => l10n.transferNotConnected,
          };
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: (isListening ? AppColors.statusError : AppColors.accent)
              .withAlpha(25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isListening ? Icons.stop_circle_outlined : Icons.download_rounded,
              color: isListening ? AppColors.statusError : AppColors.accent,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              isListening ? l10n.stopReceiving : l10n.receivePhotos,
              style: TextStyle(
                color: isListening ? AppColors.statusError : AppColors.accent,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisconnectButton extends ConsumerStatefulWidget {
  const _DisconnectButton();

  @override
  ConsumerState<_DisconnectButton> createState() => _DisconnectButtonState();
}

class _DisconnectButtonState extends ConsumerState<_DisconnectButton> {
  bool _disconnecting = false;

  Future<void> _disconnect() async {
    if (_disconnecting) return;
    setState(() => _disconnecting = true);
    try {
      final disconnected =
          await ref.read(cameraNotifierProvider.notifier).disconnect();
      if (!disconnected && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).disconnectCameraFailed),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _disconnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Tooltip(
      message: l10n.disconnectCamera,
      child: Semantics(
        button: true,
        label: l10n.disconnectCamera,
        child: GestureDetector(
          onTap: _disconnecting ? null : _disconnect,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.statusError.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.statusError.withAlpha(75),
              ),
            ),
            child: _disconnecting
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.statusError,
                    ),
                  )
                : const Icon(
                    Icons.link_off_rounded,
                    color: AppColors.statusError,
                    size: 17,
                  ),
          ),
        ),
      ),
    );
  }
}

class _ListeningStatus extends StatelessWidget {
  final SyncState syncState;

  const _ListeningStatus({required this.syncState});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isTransferring = syncState.status == SyncStatus.syncing &&
        syncState.currentObjectHandle != null;
    final progress = syncState.transferProgress.clamp(0.0, 1.0).toDouble();
    final rate = _formatTransferRate(syncState.transferRateBytesPerSecond);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accent.withAlpha(16),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const _ListeningPulse(),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.transferListeningActive,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isTransferring
                          ? l10n.transferReceivingProgress(
                              (progress * 100).round(),
                            )
                          : l10n.transferWaitingForCamera,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              Text(
                isTransferring || rate == '--'
                    ? l10n.transferRate(rate)
                    : l10n.transferLastRate(rate),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: isTransferring
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (isTransferring) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: AppColors.surfaceHighlight,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.accent),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTransferRate(double bytesPerSecond) {
    if (bytesPerSecond <= 0) return '--';
    if (bytesPerSecond >= 1024 * 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB/s';
    }
    if (bytesPerSecond >= 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    if (bytesPerSecond >= 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${bytesPerSecond.round()} B/s';
  }
}

class _ListeningPulse extends StatefulWidget {
  const _ListeningPulse();

  @override
  State<_ListeningPulse> createState() => _ListeningPulseState();
}

class _ListeningPulseState extends State<_ListeningPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.35, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _ConnectPrompt extends StatelessWidget {
  final CameraConnectionStatus status;
  const _ConnectPrompt({required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status == CameraConnectionStatus.error ? l10n.retry : l10n.connect,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
