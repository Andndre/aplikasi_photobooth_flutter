import 'dart:async';
import 'package:flutter/services.dart';

/// Service for hardware-accelerated GPU screen capture using DXGI.
/// This class provides true GPU acceleration for screen capture on Windows.
class GpuCaptureService {
  static const MethodChannel _channel = MethodChannel('dxgi_capture_plugin');
  static bool? _isSupported;

  /// Checks if the GPU capture is supported on this device
  static Future<bool> isSupported() async {
    if (_isSupported != null) {
      return _isSupported!;
    }

    try {
      _isSupported =
          await _channel.invokeMethod<bool>('isGpuCaptureSupported') ?? false;
      return _isSupported!;
    } catch (e) {
      print('Error checking GPU capture support: $e');
      _isSupported = false;
      return false;
    }
  }

  /// Capture a window using GPU acceleration
  /// This method uses DXGI's Desktop Duplication API for true GPU-accelerated capture
  ///
  /// Parameters:
  ///   hwnd - The window handle to capture
  ///
  /// Returns a map containing:
  ///   bytes: Uint8List of RGBA pixel data
  ///   width: Width of the captured image
  ///   height: Height of the captured image
  ///   isGpuAccelerated: Always true for this method
  ///   captureMethod: Will be 'dxgi_gpu'
  static Future<Map<String, dynamic>?> captureWindow(int hwnd) async {
    if (!await isSupported()) {
      print('GPU capture is not supported on this device');
      return null;
    }

    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'captureWindow',
        {'hwnd': hwnd},
      );

      if (result == null) {
        return null;
      }

      // Convert List<dynamic> to Uint8List
      final bytesList = result['bytes'] as List<Object?>;
      final Uint8List bytes = Uint8List(bytesList.length);
      for (int i = 0; i < bytesList.length; i++) {
        bytes[i] = bytesList[i] as int;
      }

      return {
        'bytes': bytes,
        'width': result['width'] as int,
        'height': result['height'] as int,
        'isDirect': true,
        'isGpuAccelerated': true,
        'captureMethod': 'dxgi_gpu',
        'originalWidth': result['originalWidth'] as int,
        'originalHeight': result['originalHeight'] as int,
      };
    } catch (e) {
      print('Error capturing window with GPU: $e');
      return null;
    }
  }
}
