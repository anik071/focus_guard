import 'package:flutter/services.dart';

class NativeBridge {
  static const _channel = MethodChannel('com.example.focus_guard/blocker');

  static Future<void> openAccessibilitySettings() async {
    await _channel.invokeMethod('openAccessibilitySettings');
  }

  static Future<void> openOverlaySettings() async {
    await _channel.invokeMethod('openOverlaySettings');
  }

  static Future<bool> hasOverlayPermission() async {
    return await _channel.invokeMethod('hasOverlayPermission') ?? false;
  }
}
