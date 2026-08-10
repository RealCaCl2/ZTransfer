import 'package:flutter/material.dart';
import 'package:ztransfer/app.dart';
import 'package:ztransfer/platform/camera_method_channel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Register the Android MethodChannel implementation as the active
  // platform transport.  On iOS (unsupported for v1) this is a no-op.
  CameraMethodChannel.register();

  runApp(const ZTransferApp());
}
