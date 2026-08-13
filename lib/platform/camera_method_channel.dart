import 'dart:async';
import 'package:flutter/services.dart';
import 'package:ztransfer/core/constants/app_constants.dart';
import 'package:ztransfer/core/logger/app_logger.dart';
import 'camera_platform_interface.dart';

/// ──────────────────────────────────────────────────────────────────────────────
/// Android MethodChannel implementation of [CameraPlatform].
///
/// Communicates with the native Kotlin PTP layer (PtpManager, etc.) over the
/// channel `com.cacl2.ztransfer/camera`.
///
/// **EventChannel** is used for the push-based event stream (ObjectAdded,
/// connection state changes, logs).  **MethodChannel** is used for
/// request/response calls (connect, disconnect, list, download, delete).
/// ──────────────────────────────────────────────────────────────────────────────

class CameraMethodChannel extends CameraPlatform {
  static const String _channelName = AppConstants.platformChannelName;
  static const String _eventChannelName =
      '${AppConstants.platformChannelName}/events';

  final MethodChannel _methodChannel = const MethodChannel(_channelName);
  final EventChannel _eventChannel = const EventChannel(_eventChannelName);

  Stream<CameraEvent>? _eventStream;

  /// Register this implementation as the active platform instance.
  /// Call once in [main] before running the app.
  static void register() {
    CameraPlatform.instance = CameraMethodChannel();
  }

  @override
  Future<bool> isConnected() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isConnected');
      return result ?? false;
    } catch (e, st) {
      appLogger.e('isConnected failed', error: e, stackTrace: st);
      return false;
    }
  }

  @override
  Future<String?> connect() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('connect');
      if (result != null) {
        final name = result['deviceName'] as String?;
        _lastTransportType = result['transportType'] as String?;
        _lastIpAddress = result['ipAddress'] as String?;
        return name;
      }
      return null;
    } catch (e, st) {
      appLogger.e('connect failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// Connect specifying a preferred transport ('USB' or 'WIFI').
  /// Native side calls connectAuto(prefer=transportType) — tries the
  /// preferred transport first, falls back to the other.
  Future<String?> connectWithTransport(String transportType) async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('connect', {
        'transportType': transportType,
      });
      if (result != null) {
        final name = result['deviceName'] as String?;
        _lastTransportType = result['transportType'] as String?;
        _lastIpAddress = result['ipAddress'] as String?;
        return name;
      }
      return null;
    } catch (e, st) {
      appLogger.e(
        'connectWithTransport($transportType) failed',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  String? _lastTransportType;
  String? _lastIpAddress;

  /// The transport type from the most recent successful connect() call.
  String? get lastTransportType => _lastTransportType;

  /// The IP address from the most recent Wi-Fi connect() call.
  String? get lastIpAddress => _lastIpAddress;

  /// Connect for transfer via Wi-Fi (already paired, no pairing code needed).
  Future<Map<String, dynamic>?> connectTransferFull(
    String host, {
    String? profileId,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<Map>(
        'connectTransfer',
        {
          'host': host,
          if (profileId != null && profileId.isNotEmpty) 'profileId': profileId,
        },
      );
      if (result != null) return Map<String, dynamic>.from(result);
      return null;
    } catch (e, st) {
      appLogger.e('connectTransferFull failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// Connect via Wi-Fi to a specific host. Used after scanning.
  /// Returns device name on success, or null on failure.
  /// Sets [needsPairing] to true if the camera requires pairing before
  /// entering "Connect to computer" mode.
  Future<String?> connectWifi(String host, {bool? needsPairing}) async {
    try {
      final result = await _methodChannel.invokeMethod<Map>(
        'connectWifi',
        {'host': host},
      );
      if (result != null) {
        _lastTransportType = result['transportType'] as String?;
        _lastIpAddress = result['ipAddress'] as String?;
        return result['deviceName'] as String?;
      }
      return null;
    } catch (e, st) {
      appLogger.e('connectWifi failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// Connect via Wi-Fi and get full result including pairing requirement.
  Future<Map<String, dynamic>?> connectWifiFull(
    String host, {
    String? profileId,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<Map>(
        'connectWifi',
        {
          'host': host,
          if (profileId != null && profileId.isNotEmpty) 'profileId': profileId,
        },
      );
      if (result != null) {
        _lastTransportType = result['transportType'] as String?;
        _lastIpAddress = result['ipAddress'] as String?;
        return Map<String, dynamic>.from(result);
      }
      return null;
    } catch (e, st) {
      appLogger.e('connectWifiFull failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// Connect via MAID3 (Connect to computer mode).
  /// [host] is the camera IP, [pairingCode] is optional 6-digit code.
  Future<Map<String, dynamic>?> connectMaid3({
    required String host,
    String? pairingCode,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<Map>(
        'connectMaid3',
        {'host': host, 'pairingCode': pairingCode},
      );
      if (result != null) return Map<String, dynamic>.from(result);
      return null;
    } catch (e, st) {
      appLogger.e('connectMaid3 failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// Start the long-lived AdvancedTransfer listener in the Android service.
  ///
  /// Returns immediately with `started`, `already_running`, or `not_connected`.
  /// Each completed photo is delivered later through the camera event channel.
  Future<Map<String, dynamic>?> startTransfer() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('startTransfer');
      if (result != null) return Map<String, dynamic>.from(result);
      return null;
    } catch (e, st) {
      appLogger.e('startTransfer failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// Stop the background AdvancedTransfer listener while keeping its PTP/IP
  /// session connected.
  Future<String?> stopTransfer() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('stopTransfer');
      return result?['status'] as String?;
    } catch (e, st) {
      appLogger.e('stopTransfer failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// Snapshot of the long-lived wireless receiver. Used when Flutter state is
  /// recreated while the native listener is still running.
  Future<Map<String, dynamic>?> getTransferStatus() async {
    try {
      final result =
          await _methodChannel.invokeMethod<Map>('getTransferStatus');
      return result == null ? null : Map<String, dynamic>.from(result);
    } catch (e, st) {
      appLogger.e('getTransferStatus failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// List saved camera profiles.
  Future<List<Map<String, dynamic>>?> listCameraProfiles() async {
    try {
      final result =
          await _methodChannel.invokeMethod<List>('listCameraProfiles');
      if (result != null) {
        return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return null;
    } catch (e, st) {
      appLogger.e('listCameraProfiles failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// Delete a saved camera profile by id.
  Future<bool> deleteCameraProfile(String id) async {
    try {
      final result = await _methodChannel
          .invokeMethod<bool>('deleteCameraProfile', {'id': id});
      return result ?? false;
    } catch (e, st) {
      appLogger.e('deleteCameraProfile failed', error: e, stackTrace: st);
      return false;
    }
  }

  /// Run camera compatibility check with saved profile.
  Future<Map<String, dynamic>?> runCompatibilityCheck(String ip) async {
    try {
      final result =
          await _methodChannel.invokeMethod<Map>('runCompatibilityCheck', {
        'ip': ip,
      });
      if (result != null) return Map<String, dynamic>.from(result);
      return null;
    } catch (e, st) {
      appLogger.e('runCompatibilityCheck failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// Legacy compatibility check. Current transfer sessions do not send
  /// ChangeApplicationMode; this now reports whether the Wi-Fi session is ready.
  Future<bool> enableTransferMode() async {
    try {
      final result =
          await _methodChannel.invokeMethod<bool>('enableTransferMode');
      return result ?? false;
    } catch (e, st) {
      appLogger.e('enableTransferMode failed', error: e, stackTrace: st);
      return false;
    }
  }

  /// Submit ConfirmPairing, wait for the user to press OK on the camera, then
  /// close the pairing session, save the profile and start a fresh transfer
  /// connection in the background without ChangeApplicationMode.
  /// Returns {ok, deviceName} on success, {ok: false, error} on failure.
  Future<Map<String, dynamic>?> completePairing() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('completePairing');
      if (result != null) return Map<String, dynamic>.from(result);
      return null;
    } catch (e, st) {
      appLogger.e('completePairing failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// Get the pairing code from the camera (for "Connect to computer" mode).
  /// Camera returns an N-digit challenge that the user must confirm on the camera.
  Future<String?> getPairingCode() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('getPairingCode');
      if (result != null) return result['code'] as String?;
      return null;
    } catch (e, st) {
      appLogger.e('getPairingCode failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// Confirm pairing on the camera (for "Connect to computer" mode).
  Future<bool> confirmPairing() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('confirmPairing');
      return result ?? false;
    } catch (e, st) {
      appLogger.e('confirmPairing failed', error: e, stackTrace: st);
      return false;
    }
  }

  /// Run a comprehensive network probe (mDNS + port scan) to discover
  /// what services the camera exposes. Useful for debugging.
  Future<Map<String, dynamic>?> networkProbe() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('networkProbe');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } catch (e, st) {
      appLogger.e('networkProbe failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// Scan the local Wi-Fi subnet for a Nikon PTP/IP camera.
  /// Returns a map with 'ip' and 'cameraName' on success, null if not found.
  Future<Map<String, dynamic>?> scanCamera() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('scanCamera');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } catch (e, st) {
      appLogger.e('scanCamera failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// Auto-connect: tries USB first, then Wi-Fi.
  /// Returns a map with 'deviceName' and 'transportType' on success.
  Future<Map<String, dynamic>?> connectAuto() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('connectAuto');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } catch (e, st) {
      appLogger.e('connectAuto failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// Connect with a preferred transport type.
  Future<Map<String, dynamic>?> connectWith({
    required String transportType,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<Map>(
        'connect',
        {'transportType': transportType},
      );
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } catch (e, st) {
      appLogger.e(
        'connectWith($transportType) failed',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  @override
  Stream<CameraEvent> get eventStream {
    _eventStream ??=
        _eventChannel.receiveBroadcastStream().map<CameraEvent>((dynamic data) {
      try {
        if (data is! Map) {
          appLogger.w('EventChannel: non-Map payload: $data');
          return LogEvent(
            level: 'ERROR',
            message: 'Invalid event payload: $data',
          );
        }
        final event = _parseEvent(data);
        appLogger.d('EventChannel received: ${event.runtimeType}');
        return event;
      } catch (e, st) {
        appLogger.e('EventChannel parse error', error: e, stackTrace: st);
        return LogEvent(level: 'ERROR', message: 'Parse error: $e');
      }
    });
    return _eventStream!;
  }

  @override
  Future<List<Map<String, dynamic>>> listCameraPhotos() async {
    try {
      final result =
          await _methodChannel.invokeListMethod<Map<dynamic, dynamic>>(
        'listCameraPhotos',
      );
      if (result == null) return [];
      return result.map((m) => Map<String, dynamic>.from(m)).toList();
    } catch (e, st) {
      appLogger.e('listCameraPhotos failed', error: e, stackTrace: st);
      return [];
    }
  }

  @override
  Future<String?> downloadPhoto(int objectHandle) async {
    try {
      final result = await _methodChannel.invokeMethod<String>(
        'downloadPhoto',
        {'objectHandle': objectHandle},
      );
      return result;
    } catch (e, st) {
      appLogger.e('downloadPhoto failed', error: e, stackTrace: st);
      return null;
    }
  }

  @override
  @override
  Future<bool> deleteLocalPhoto(String filePath) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'deleteLocalPhoto',
        {'filePath': filePath},
      );
      return result ?? false;
    } catch (e, st) {
      appLogger.e('deleteLocalPhoto failed', error: e, stackTrace: st);
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>?> getExifData(String filePath) async {
    try {
      final result = await _methodChannel.invokeMapMethod<String, dynamic>(
        'getExifData',
        {'filePath': filePath},
      );
      return result;
    } catch (e, st) {
      appLogger.e('getExifData failed', error: e, stackTrace: st);
      return null;
    }
  }

  @override
  Future<bool> shareFile(String filePath) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'shareFile',
        {'filePath': filePath},
      );
      return result ?? false;
    } catch (e, st) {
      appLogger.e('shareFile failed', error: e, stackTrace: st);
      return false;
    }
  }

  @override
  Future<bool> shareMultipleFiles(List<String> filePaths) async {
    try {
      await _methodChannel.invokeMethod(
        'shareMultipleFiles',
        {'filePaths': filePaths},
      );
      return true;
    } catch (e, st) {
      appLogger.e('shareMultipleFiles failed', error: e, stackTrace: st);
      return false;
    }
  }

  @override
  Future<int> deleteMultiplePhotos(List<String> filePaths) async {
    try {
      final result = await _methodChannel.invokeMethod<int>(
        'deleteMultiplePhotos',
        {'filePaths': filePaths},
      );
      return result ?? 0;
    } catch (e, st) {
      appLogger.e('deleteMultiplePhotos failed', error: e, stackTrace: st);
      return 0;
    }
  }

  // ── Project CRUD ────────────────────────────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> listProjects() async {
    try {
      final result = await _methodChannel
          .invokeListMethod<Map<dynamic, dynamic>>('listProjects');
      if (result == null) return [];
      return result.map((m) => Map<String, dynamic>.from(m)).toList();
    } catch (e, st) {
      appLogger.e('listProjects failed', error: e, stackTrace: st);
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>?> createProject(String name) async {
    try {
      final result = await _methodChannel.invokeMapMethod<String, dynamic>(
        'createProject',
        {'name': name},
      );
      return result;
    } catch (e, st) {
      appLogger.e('createProject failed', error: e, stackTrace: st);
      return null;
    }
  }

  @override
  Future<bool> updateProject(String id, String name) async {
    try {
      final r = await _methodChannel
          .invokeMethod<bool>('updateProject', {'id': id, 'name': name});
      return r ?? false;
    } catch (e, st) {
      appLogger.e('updateProject failed', error: e, stackTrace: st);
      return false;
    }
  }

  @override
  Future<bool> deleteProject(String id, bool deletePhotos) async {
    try {
      final r = await _methodChannel.invokeMethod<bool>(
        'deleteProject',
        {'id': id, 'deletePhotos': deletePhotos},
      );
      return r ?? false;
    } catch (e, st) {
      appLogger.e('deleteProject failed', error: e, stackTrace: st);
      return false;
    }
  }

  @override
  Future<bool> setActiveProject(String? id) async {
    try {
      await _methodChannel.invokeMethod('setActiveProject', {'id': id ?? ''});
      return true;
    } catch (e, st) {
      appLogger.e('setActiveProject failed', error: e, stackTrace: st);
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>?> getActiveProject() async {
    try {
      return await _methodChannel
          .invokeMapMethod<String, dynamic>('getActiveProject');
    } catch (e, st) {
      appLogger.e('getActiveProject failed', error: e, stackTrace: st);
      return null;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listLocalPhotos({
    String? projectId,
  }) async {
    try {
      final result =
          await _methodChannel.invokeListMethod<Map<dynamic, dynamic>>(
        'listLocalPhotos',
        {'projectId': projectId},
      );
      if (result == null) return [];
      return result.map((m) => Map<String, dynamic>.from(m)).toList();
    } catch (e, st) {
      appLogger.e('listLocalPhotos failed', error: e, stackTrace: st);
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listAllLocalPhotos() async {
    try {
      final result = await _methodChannel
          .invokeListMethod<Map<dynamic, dynamic>>('listAllLocalPhotos');
      if (result == null) return [];
      return result.map((m) => Map<String, dynamic>.from(m)).toList();
    } catch (e, st) {
      appLogger.e('listAllLocalPhotos failed', error: e, stackTrace: st);
      return [];
    }
  }

  @override
  Future<String?> getTransportType() async {
    try {
      return await _methodChannel.invokeMethod<String>('getTransportType');
    } catch (e, st) {
      appLogger.e('getTransportType failed', error: e, stackTrace: st);
      return null;
    }
  }

  @override
  Future<int?> getBatteryLevel() async {
    try {
      return await _methodChannel.invokeMethod<int>('getBatteryLevel');
    } catch (e, st) {
      appLogger.e('getBatteryLevel failed', error: e, stackTrace: st);
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> getStorageInfo() async {
    try {
      final result = await _methodChannel.invokeMapMethod<String, dynamic>(
        'getStorageInfo',
      );
      return result;
    } catch (e, st) {
      appLogger.e('getStorageInfo failed', error: e, stackTrace: st);
      return null;
    }
  }

  Future<Map<String, dynamic>?> getSessionDiagnostics() async {
    try {
      return await _methodChannel.invokeMapMethod<String, dynamic>(
        'getSessionDiagnostics',
      );
    } catch (e, st) {
      appLogger.e('getSessionDiagnostics failed', error: e, stackTrace: st);
      return null;
    }
  }

  // ── Event parsing ─────────────────────────────────────────────────────────

  CameraEvent _parseEvent(Map<dynamic, dynamic> data) {
    final type = data['type'] as String? ?? 'unknown';

    return switch (type) {
      'objectAdded' => ObjectAddedEvent(
          objectHandle: (data['objectHandle'] as num).toInt(),
          formatCode: (data['formatCode'] as num).toInt(),
          fileName: data['fileName'] as String? ?? 'unknown',
          sizeBytes: (data['sizeBytes'] as num).toInt(),
          localPath: data['localPath'] as String?,
          width: (data['width'] as num?)?.toInt(),
          height: (data['height'] as num?)?.toInt(),
          isRaw: data['isRaw'] as bool? ?? false,
        ),
      'objectRemoved' => ObjectRemovedEvent(
          objectHandle: (data['objectHandle'] as num).toInt(),
        ),
      'connectionStateChanged' => ConnectionStateChangedEvent(
          connected: data['connected'] as bool? ?? false,
          deviceName: data['deviceName'] as String?,
          transportType: data['transportType'] as String?,
        ),
      'batteryChanged' => BatteryChangedEvent(
          level: (data['level'] as num?)?.toInt() ?? 0,
        ),
      'storageChanged' => StorageChangedEvent(
          freeSpaceBytes: (data['freeSpaceBytes'] as num?)?.toInt() ?? 0,
          maxCapacityBytes: (data['maxCapacityBytes'] as num?)?.toInt() ?? 0,
          freeImages: (data['freeImages'] as num?)?.toInt() ?? 0,
        ),
      'transferProgress' => TransferProgressEvent(
          objectHandle: (data['objectHandle'] as num).toInt(),
          progress: (data['progress'] as num).toDouble(),
          bytesTransferred: (data['bytesTransferred'] as num?)?.toInt() ?? 0,
          totalBytes: (data['totalBytes'] as num?)?.toInt() ?? 0,
          bytesPerSecond: (data['bytesPerSecond'] as num?)?.toDouble() ?? 0,
        ),
      'transferStateChanged' => TransferStateChangedEvent(
          listening: data['listening'] as bool? ?? false,
        ),
      'log' => LogEvent(
          level: data['level'] as String? ?? 'INFO',
          message: data['message'] as String? ?? '',
        ),
      _ => LogEvent(level: 'ERROR', message: 'Unknown event type: $type'),
    };
  }
}
