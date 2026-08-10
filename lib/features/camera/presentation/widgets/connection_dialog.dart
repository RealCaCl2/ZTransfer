import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ztransfer/app_router.dart';
import 'package:ztransfer/core/theme/app_colors.dart';
import 'package:ztransfer/features/camera/presentation/camera_notifier.dart';
import 'package:ztransfer/l10n/generated/app_localizations.dart';
import 'package:ztransfer/platform/camera_method_channel.dart';
import 'package:ztransfer/platform/camera_platform_interface.dart';

enum _Step {
  choose,
  usbConnecting,
  wifiScan,
  wifiPairing,
  wifiConfirming,
  wifiConnecting,
}

class ConnectionDialog extends ConsumerStatefulWidget {
  const ConnectionDialog({super.key});
  @override
  ConsumerState<ConnectionDialog> createState() => _ConnectionDialogState();
}

class _ConnectionDialogState extends ConsumerState<ConnectionDialog> {
  _Step _step = _Step.choose;
  String _wifiHost = '';
  String _pairingCode = '';
  String _status = '';
  String _diagLog = '';

  List<Map<String, dynamic>> _discovered = [];
  List<Map<String, dynamic>> _profiles = [];
  StreamSubscription<CameraEvent>? _logSub;
  bool _dialogClosing = false;
  bool _isScanning = false;

  void _closeAfterConnectionSuccess() {
    if (!mounted || _dialogClosing) return;
    _dialogClosing = true;
    Navigator.of(context).pop();
  }

  void _openWirelessTutorial() {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(AppRoute.tutorial);
  }

  Future<void> _loadProfiles() async {
    final channel = CameraMethodChannel();
    final result = await channel.listCameraProfiles();
    if (mounted && result != null) {
      setState(() {
        _profiles = List<Map<String, dynamic>>.from(result);
      });
    }
  }

  Widget _buildSavedProfiles() {
    if (_profiles.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('已配对的相机',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 6),
        ..._profiles.map((p) => _SavedProfileTile(
              name: p['cameraName'] as String? ?? 'Nikon',
              ip: p['lastIp'] as String? ?? '',
              onTap: () => _connectDirect(
                p['lastIp'] as String? ?? '',
                p['id'] as String? ?? '',
              ),
              onDelete: () {
                setState(() {
                  _profiles.remove(p);
                });
                final c = CameraMethodChannel();
                c.deleteCameraProfile(p['id'] as String? ?? '');
              },
            )),
      ],
    );
  }

  Future<void> _connectDirect(String ip, String profileId) async {
    if (ip.isEmpty || profileId.isEmpty) return;
    setState(() {
      _step = _Step.wifiConnecting;
      _status = '连接 $ip ...';
    });
    _wifiHost = ip;
    final result = await CameraMethodChannel().connectTransferFull(
      ip,
      profileId: profileId,
    );
    if (!mounted) return;
    if (result != null) {
      ref.read(cameraNotifierProvider.notifier).useExistingWifiConnection(
            host: ip,
            deviceName: result['deviceName'] as String?,
          );
      _closeAfterConnectionSuccess();
    } else {
      setState(() {
        _step = _Step.wifiScan;
        _status = '连接失败，请检查 IP 和网络';
      });
    }
  }

  bool get _busy =>
      _step == _Step.usbConnecting ||
      _step == _Step.wifiConfirming ||
      _step == _Step.wifiConnecting;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
    _logSub = CameraPlatform.instance.eventStream.listen((event) {
      if (!mounted) return;
      if (event is ConnectionStateChangedEvent && event.connected) {
        _closeAfterConnectionSuccess();
        return;
      }
      if (event is LogEvent) {
        setState(() {
          _diagLog += '${event.message}\n';
          if (_diagLog.length > 2000) {
            _diagLog = _diagLog.substring(_diagLog.length - 2000);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _logSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cam = ref.watch(cameraNotifierProvider);

    return AlertDialog(
      title: Row(children: [
        Icon(
            _busy || _isScanning
                ? Icons.sync_rounded
                : Icons.camera_alt_rounded,
            color: AppColors.accent,
            size: 22),
        const SizedBox(width: 10),
        Text(_titleText(),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 18)),
      ]),
      content: SizedBox(
        width: 340,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _buildStatusLine(cam),
          const SizedBox(height: 16),
          ..._buildStepContent(),
          if (_diagLog.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 150),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF333333)),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _diagLog,
                  style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 10,
                      fontFamily: 'monospace',
                      height: 1.4),
                ),
              ),
            ),
          ],
        ]),
      ),
      actions: _buildActions(),
    );
  }

  String _titleText() {
    final l10n = AppLocalizations.of(context);
    return switch (_step) {
      _Step.choose => '连接相机',
      _Step.usbConnecting => 'USB 连接中',
      _Step.wifiScan => '扫描相机',
      _Step.wifiPairing => '相机配对',
      _Step.wifiConfirming => l10n.pairingWaitingCameraTitle,
      _Step.wifiConnecting => 'Wi-Fi 连接中',
    };
  }

  List<Widget> _buildStepContent() {
    return switch (_step) {
      _Step.choose => [
          _buildTransportChoice(),
          const SizedBox(height: 12),
          _buildSavedProfiles()
        ],
      _Step.usbConnecting => [_buildConnectingIndicator('正在通过 USB 连接相机...')],
      _Step.wifiScan => [_buildWifiScanView()],
      _Step.wifiPairing => [_buildPairingView()],
      _Step.wifiConfirming => [_buildPairingView(submitted: true)],
      _Step.wifiConnecting => [
          _buildConnectingIndicator(
            _status.isNotEmpty ? _status : '正在建立 Wi-Fi 连接...',
          ),
        ],
    };
  }

  List<Widget> _buildActions() {
    if (_step == _Step.choose) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      ];
    }
    if (_busy) {
      return [
        TextButton(
          onPressed: null,
          child:
              const Text('取消', style: TextStyle(color: AppColors.textTertiary)),
        ),
      ];
    }
    return [
      TextButton(
        onPressed: () => setState(() => _step = _Step.choose),
        child:
            const Text('返回', style: TextStyle(color: AppColors.textSecondary)),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child:
            const Text('关闭', style: TextStyle(color: AppColors.textSecondary)),
      ),
    ];
  }

  // ── Status line ─────────────────────────────────────────────────────

  Widget _buildStatusLine(CameraState cam) {
    final (label, color) = switch (cam.status) {
      CameraConnectionStatus.connected => (
          '已连接 · ${cam.deviceName ?? "Nikon"}',
          AppColors.statusConnected
        ),
      CameraConnectionStatus.connecting => ('正在连接...', AppColors.statusSyncing),
      CameraConnectionStatus.error => (
          cam.errorMessage ?? '连接失败',
          AppColors.statusError
        ),
      CameraConnectionStatus.disconnected => (
          '未连接',
          AppColors.statusDisconnected
        ),
    };
    final icon = switch (cam.connectionType) {
      ConnectionType.usb => Icons.usb_rounded,
      ConnectionType.wifi => Icons.wifi_rounded,
      ConnectionType.none => null,
    };
    return Row(children: [
      Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      if (icon != null) ...[
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4)
      ],
      Expanded(
          child: Text(label,
              style: TextStyle(color: color, fontSize: 12),
              overflow: TextOverflow.ellipsis)),
      if (cam.batteryLevel != null)
        Text('${cam.batteryLevel}%',
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
    ]);
  }

  // ── Step: Choose transport ──────────────────────────────────────────

  Widget _buildTransportChoice() {
    return Column(children: [
      _TransportCard(
        icon: Icons.usb_rounded,
        title: 'USB 有线连接',
        subtitle: '通过 OTG 线缆连接相机\n使用 PTP/MTP 协议，即插即用',
        accentColor: AppColors.accent,
        onTap: _doUsbConnect,
      ),
      const SizedBox(height: 10),
      _TransportCard(
        icon: Icons.wifi_rounded,
        title: 'Wi-Fi 无线连接',
        subtitle: '通过 Wi-Fi 连接相机\n需在相机开启「连接到计算机」',
        accentColor: AppColors.accent,
        onTap: () => setState(() {
          _step = _Step.wifiScan;
          _status = '';
        }),
      ),
    ]);
  }

  // ── Step: USB connecting ────────────────────────────────────────────

  Widget _buildConnectingIndicator(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(children: [
        const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: AppColors.accent)),
        const SizedBox(height: 16),
        Text(message,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            textAlign: TextAlign.center),
      ]),
    );
  }

  // ── Step: Wi-Fi scan ────────────────────────────────────────────────

  Widget _buildWifiScanView() {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 40,
          child: ElevatedButton.icon(
            onPressed: _isScanning ? null : _doScan,
            icon: _isScanning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Icon(Icons.wifi_find_rounded, size: 18),
            label: Text(
              _isScanning
                  ? l10n.scanNetworkCameraInProgress
                  : l10n.scanNetworkCamera,
              style: const TextStyle(fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        if (_status.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_status,
              style:
                  const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
        ],
        if (_discovered.isNotEmpty) ...[
          const SizedBox(height: 10),
          ..._discovered.map((d) => _CameraTile(
                host: d['ip'] as String,
                name: d['cameraName'] as String? ?? 'Nikon',
                method: d['method'] as String? ?? '',
                onTap: () => _doWifiConnect(d['ip'] as String),
              )),
        ],
        const SizedBox(height: 12),
        const Divider(color: AppColors.textTertiary, height: 1),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: TextEditingController(text: _wifiHost),
              onChanged: (v) => _wifiHost = v,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: '手动输入 IP 地址',
                hintStyle: const TextStyle(
                    color: AppColors.textTertiary, fontSize: 12),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.textTertiary)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.accent)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 38,
            child: ElevatedButton(
              onPressed:
                  _wifiHost.isEmpty ? null : () => _doWifiConnect(_wifiHost),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              child: const Text('连接',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _openWirelessTutorial,
            icon: const Icon(Icons.menu_book_outlined, size: 17),
            label: Text(l10n.wirelessTutorialLink),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }

  // ── Step: Wi-Fi pairing ─────────────────────────────────────────────

  Widget _buildPairingView({bool submitted = false}) {
    final l10n = AppLocalizations.of(context);
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          const Icon(Icons.lock_outline_rounded,
              color: AppColors.accent, size: 36),
          const SizedBox(height: 10),
          Text(
              submitted
                  ? l10n.pairingRequestSubmittedTitle
                  : l10n.pairingRequestTitle,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (_pairingCode.isNotEmpty)
            Text(_pairingCode,
                style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 8))
          else
            const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.accent)),
          const SizedBox(height: 12),
          Text(
              submitted
                  ? l10n.pairingAfterSubmitInstructions
                  : l10n.pairingBeforeSubmitInstructions,
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              textAlign: TextAlign.center),
        ]),
      ),
      if (_status.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(_status,
            style:
                const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
      ],
      const SizedBox(height: 14),
      if (submitted)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              l10n.pairingWaitingCameraConfirmation,
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        )
      else
        SizedBox(
          width: double.infinity,
          height: 40,
          child: ElevatedButton.icon(
            onPressed: _doConfirmPairing,
            icon: const Icon(Icons.send_rounded, size: 18),
            label: Text(
              l10n.pairingSubmitCode,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
          ),
        ),
    ]);
  }

  // ── Actions ─────────────────────────────────────────────────────────

  Future<void> _doUsbConnect() async {
    setState(() => _step = _Step.usbConnecting);
    try {
      final notifier = ref.read(cameraNotifierProvider.notifier);
      await notifier.connectUsb();
      if (!mounted) return;
      final cam = ref.read(cameraNotifierProvider);
      if (cam.status == CameraConnectionStatus.connected) {
        _closeAfterConnectionSuccess();
      } else {
        setState(() {
          _step = _Step.choose;
          _status = cam.errorMessage ?? 'USB 连接失败';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _Step.choose;
        _status = 'USB 连接异常: $e';
      });
    }
  }

  Future<void> _doScan() async {
    if (_isScanning) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isScanning = true;
      _step = _Step.wifiScan;
      _status = l10n.scanCurrentNetworkStatus;
      _discovered = [];
    });
    try {
      final channel = CameraMethodChannel();
      final result = await channel.scanCamera().timeout(
            const Duration(seconds: 20),
          );
      if (!mounted) return;
      if (result != null) {
        setState(() {
          _discovered = [result];
          _wifiHost = result['ip'] as String? ?? '';
          _status =
              '发现相机: ${result['cameraName'] ?? "Nikon"} @ ${result['ip']}';
        });
      } else {
        setState(() {
          _status = l10n.scanNotFoundHint;
        });
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _status = l10n.scanTimeoutHint;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = l10n.scanFailed(e.toString());
      });
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _doWifiConnect(String host) async {
    if (host.isEmpty) return;
    _wifiHost = host;
    setState(() {
      _step = _Step.wifiConnecting;
      _status = '连接 $host ...';
      _diagLog = '';
    });
    try {
      final result = await CameraMethodChannel().connectWifiFull(host);
      if (!mounted) return;

      if (result == null) {
        setState(() {
          _step = _Step.wifiScan;
          _status = '连接失败，请检查 IP 和网络';
        });
        return;
      }

      final needsPairing = result['needsPairing'] == true;
      final pairingCode = result['pairingCode'] as String?;

      if (!needsPairing) {
        ref.read(cameraNotifierProvider.notifier).useExistingWifiConnection(
              host: host,
              deviceName: result['deviceName'] as String?,
            );
        _closeAfterConnectionSuccess();
        return;
      }

      // Show pairing code
      if (pairingCode != null && pairingCode.isNotEmpty) {
        setState(() {
          _step = _Step.wifiPairing;
          _pairingCode = pairingCode;
        });
      } else {
        setState(() {
          _step = _Step.wifiScan;
          _status = '无法获取配对码，请重试';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _Step.wifiScan;
        _status = '连接异常: $e';
      });
    }
  }

  Future<void> _doConfirmPairing() async {
    if (_step != _Step.wifiPairing) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _step = _Step.wifiConfirming;
      _status = '';
    });
    try {
      final channel = CameraMethodChannel();
      final result = await channel.completePairing();
      if (!mounted) return;

      if (result == null || result['ok'] != true) {
        final error = result?['error'] as String? ?? l10n.pairingFailed;
        setState(() {
          _step = _Step.wifiPairing;
          _status = error;
        });
        return;
      }

      if (result['connected'] == true) {
        ref.read(cameraNotifierProvider.notifier).useExistingWifiConnection(
              host: _wifiHost,
              deviceName: result['deviceName'] as String?,
            );
        _closeAfterConnectionSuccess();
        return;
      }

      // The native side normally returns only after a fresh transfer session
      // is ready. Keep this page visible if an older implementation reports
      // the app-side acknowledgement before the camera-side OK.
      setState(() => _status = l10n.pairingWaitingCameraConfirmation);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _Step.wifiPairing;
        _status = l10n.pairingConfirmException(e.toString());
      });
    }
  }
}

// ── Saved profile tile ──────────────────────────────────────────────

class _SavedProfileTile extends StatelessWidget {
  final String name, ip;
  final VoidCallback onTap, onDelete;
  const _SavedProfileTile(
      {required this.name,
      required this.ip,
      required this.onTap,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.2), width: 1),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: const Icon(Icons.camera_alt_rounded,
            color: AppColors.accent, size: 20),
        title: Text(name,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        subtitle: Text(ip,
            style:
                const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline,
              color: AppColors.textTertiary, size: 16),
          onPressed: onDelete,
          padding: EdgeInsets.zero,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _TransportCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  const _TransportCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.surfaceHighlight, width: 1),
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: accentColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          height: 1.4)),
                ])),
            const Icon(Icons.chevron_right,
                color: AppColors.textTertiary, size: 22),
          ]),
        ),
      ),
    );
  }
}

// ── Camera tile widget ────────────────────────────────────────────────

class _CameraTile extends StatelessWidget {
  final String host, name, method;
  final VoidCallback onTap;
  const _CameraTile(
      {required this.host,
      required this.name,
      required this.method,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          const Icon(Icons.camera_alt_rounded,
              color: AppColors.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                Text('$host${method.isNotEmpty ? ' · $method' : ''}',
                    style: const TextStyle(
                        color: AppColors.textTertiary, fontSize: 11)),
              ])),
          const Icon(Icons.chevron_right,
              color: AppColors.textTertiary, size: 18),
        ]),
      ),
    );
  }
}
