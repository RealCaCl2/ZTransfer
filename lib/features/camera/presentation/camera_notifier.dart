import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ztransfer/features/camera/data/camera_repository.dart';
import 'package:ztransfer/platform/camera_platform_interface.dart';

part 'camera_notifier.g.dart';

/// Immutable snapshot of the camera connection state.
enum CameraConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

/// Type of physical connection to the camera.
enum ConnectionType {
  usb,
  wifi,
  none,
}

class CameraState {
  final CameraConnectionStatus status;
  final String? deviceName;
  final String? errorMessage;
  final ConnectionType connectionType;
  final int? batteryLevel;
  final String? ipAddress;

  const CameraState({
    this.status = CameraConnectionStatus.disconnected,
    this.deviceName,
    this.errorMessage,
    this.connectionType = ConnectionType.none,
    this.batteryLevel,
    this.ipAddress,
  });

  CameraState copyWith({
    CameraConnectionStatus? status,
    String? deviceName,
    String? errorMessage,
    ConnectionType? connectionType,
    int? batteryLevel,
    bool clearBattery = false,
    String? ipAddress,
    bool clearIp = false,
  }) {
    return CameraState(
      status: status ?? this.status,
      deviceName: deviceName ?? this.deviceName,
      errorMessage: errorMessage,
      connectionType: connectionType ?? this.connectionType,
      batteryLevel: clearBattery ? null : (batteryLevel ?? this.batteryLevel),
      ipAddress: clearIp ? null : (ipAddress ?? this.ipAddress),
    );
  }

  bool get isConnected => status == CameraConnectionStatus.connected;
}

/// Manages the USB camera connection lifecycle.
///
/// Listens to [CameraPlatform.eventStream] for connection-state changes
/// pushed from the native layer, so the UI reflects reality without polling.
@riverpod
class CameraNotifier extends _$CameraNotifier {
  StreamSubscription<CameraEvent>? _eventSub;

  @override
  CameraState build() {
    _listenToEvents();
    // Immediately check current state
    _checkInitialState();
    ref.onDispose(() {
      _eventSub?.cancel();
    });
    return const CameraState();
  }

  Future<void> _checkInitialState() async {
    final repo = ref.read(cameraRepositoryProvider);
    final connected = await repo.isConnected();
    if (connected) {
      final transport = await repo.getTransportType();
      final diagnostics = await repo.getSessionDiagnostics();
      final restoredName = diagnostics?['cameraName'] as String?;
      final restoredHost = diagnostics?['host'] as String?;
      final restoredTransport =
          transport ?? diagnostics?['transportType'] as String?;
      state = state.copyWith(
        status: CameraConnectionStatus.connected,
        deviceName: restoredName?.isNotEmpty == true ? restoredName : null,
        connectionType: _parseTransportType(restoredTransport),
        ipAddress: restoredHost?.isNotEmpty == true ? restoredHost : null,
      );
    }
  }

  void _listenToEvents() {
    final repo = ref.read(cameraRepositoryProvider);
    _eventSub = repo.eventStream.listen((event) {
      if (event is ConnectionStateChangedEvent) {
        state = state.copyWith(
          status: event.connected
              ? CameraConnectionStatus.connected
              : CameraConnectionStatus.disconnected,
          deviceName: event.deviceName,
          errorMessage: null,
          connectionType: event.connected
              ? _parseTransportType(event.transportType)
              : ConnectionType.none,
          clearBattery: true,
        );
      } else if (event is BatteryChangedEvent) {
        state = state.copyWith(batteryLevel: event.level);
      }
    });
  }

  /// Connect via USB (PTP/MTP over USB OTG).
  Future<void> connectUsb() async {
    if (state.status == CameraConnectionStatus.connecting ||
        state.status == CameraConnectionStatus.connected) {
      return;
    }
    state = state.copyWith(
      status: CameraConnectionStatus.connecting,
      errorMessage: null,
      connectionType: ConnectionType.usb,
      clearIp: true,
    );
    final repo = ref.read(cameraRepositoryProvider);
    final deviceName = await repo.connectWithTransport('USB');
    _applyConnectResult(deviceName, ConnectionType.usb);
  }

  /// Connect via Wi-Fi to a specific host IP.
  Future<void> connectWifi({required String host}) async {
    if (state.status == CameraConnectionStatus.connecting ||
        state.status == CameraConnectionStatus.connected) {
      return;
    }
    state = state.copyWith(
      status: CameraConnectionStatus.connecting,
      errorMessage: null,
      connectionType: ConnectionType.wifi,
      ipAddress: host,
    );
    final repo = ref.read(cameraRepositoryProvider);
    final deviceName = await repo.connectWifi(host);
    _applyConnectResult(deviceName, ConnectionType.wifi);
  }

  void useExistingWifiConnection({
    required String host,
    String? deviceName,
  }) {
    state = state.copyWith(
      status: CameraConnectionStatus.connected,
      deviceName: deviceName,
      errorMessage: null,
      connectionType: ConnectionType.wifi,
      ipAddress: host,
    );
  }

  void _applyConnectResult(String? deviceName, ConnectionType type) {
    if (deviceName != null) {
      _checkInitialState();
      state = state.copyWith(
        status: CameraConnectionStatus.connected,
        deviceName: deviceName,
        connectionType: type,
      );
    } else {
      state = state.copyWith(
        status: CameraConnectionStatus.error,
        errorMessage: type == ConnectionType.usb
            ? '未检测到 USB 相机，请检查 OTG 连接'
            : 'Wi-Fi 连接失败，请检查 IP 和网络',
        connectionType: ConnectionType.none,
        clearBattery: true,
        clearIp: true,
      );
    }
  }

  Future<void> connect({ConnectionType? prefer}) async {
    if (state.status == CameraConnectionStatus.connecting ||
        state.status == CameraConnectionStatus.connected) {
      return;
    }

    state = state.copyWith(
      status: CameraConnectionStatus.connecting,
      errorMessage: null,
      connectionType: prefer ?? ConnectionType.none,
      clearIp: true,
    );

    final repo = ref.read(cameraRepositoryProvider);
    final transportStr = prefer == ConnectionType.usb
        ? 'USB'
        : prefer == ConnectionType.wifi
            ? 'WIFI'
            : null;
    final deviceName = transportStr != null
        ? await repo.connectWithTransport(transportStr)
        : await repo.connect();

    if (deviceName != null) {
      final actualTransportStr = await repo.getTransportType();
      final transportType = _parseTransportType(actualTransportStr);

      state = state.copyWith(
        status: CameraConnectionStatus.connected,
        deviceName: deviceName,
        connectionType: transportType,
      );
    } else {
      state = state.copyWith(
        status: CameraConnectionStatus.error,
        errorMessage: 'Failed to connect to camera',
        connectionType: ConnectionType.none,
        clearBattery: true,
        clearIp: true,
      );
    }
  }

  ConnectionType _parseTransportType(String? str) {
    return switch (str?.toUpperCase()) {
      'USB' => ConnectionType.usb,
      'WIFI' => ConnectionType.wifi,
      _ => ConnectionType.none,
    };
  }
}

// ── Provider for the repository ──────────────────────────────────────────────

@riverpod
CameraRepository cameraRepository(CameraRepositoryRef ref) {
  return CameraRepository();
}
