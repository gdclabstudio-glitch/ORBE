import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ScreenProtectionService {
  static const MethodChannel _channel = MethodChannel(
    'labomba_app/screen_protection',
  );

  static Future<void> enable() async {
    await _channel.invokeMethod<void>('enable');
  }

  static Future<void> disable() async {
    await _channel.invokeMethod<void>('disable');
  }
}

class SecureScreen extends StatefulWidget {
  final Widget child;

  const SecureScreen({super.key, required this.child});

  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen> {
  @override
  void initState() {
    super.initState();
    ScreenProtectionService.enable();
  }

  @override
  void dispose() {
    ScreenProtectionService.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
