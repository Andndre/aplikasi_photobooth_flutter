import 'dart:async';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:win32/win32.dart';
import 'package:photobooth/services/gpu_capture_service.dart';

// CaptureMethod enum yang sama dari file asli
enum CaptureMethod {
  standard, // Standard BitBlt method
  printWindow, // PrintWindow API - works well for most apps
  fullscreen, // Special mode for fullscreen applications including OBS
}

// WindowInfo class yang sama dari file asli
class WindowInfo {
  final int hwnd;
  final String title;

  WindowInfo({required this.hwnd, required this.title});
}

// Temporary storage for collecting window information during enumeration
class _WindowCollection {
  static List<WindowInfo> windows = [];

  // Reset the windows list
  static void clear() {
    windows = [];
  }

  // Add a window to the collection
  static void addWindow(int hwnd, String title) {
    windows.add(WindowInfo(hwnd: hwnd, title: title));
  }
}

// Static callback function for EnumWindows - this must be top-level or static
int _enumWindowsProc(int hwnd, int lParam) {
  try {
    if (IsWindowVisible(hwnd) != 0) {
      final buffer = calloc<Uint16>(1024).cast<Utf16>();
      final titleLength = GetWindowText(hwnd, buffer, 1024);

      if (titleLength > 0) {
        final title = buffer.toDartString();

        // Filter out empty titles and system windows
        if (title.isNotEmpty &&
            !title.contains('Default IME') &&
            !title.contains('MSCTFIME UI') &&
            !title.contains('Windows Input Experience')) {
          // Filter out this application's own window to prevent capturing itself
          if (!title.toLowerCase().contains('photobooth')) {
            _WindowCollection.addWindow(hwnd, title);
          }
        }
      }

      calloc.free(buffer);
    }
  } catch (e) {
    print('Error in enumWindowsCallback: $e');
  }

  return TRUE; // Continue enumeration
}

class ScreenCaptureService {
  // Track frame capture performance
  int _frameCount = 0;
  DateTime _lastFpsUpdateTime = DateTime.now();
  double _currentFps = 0;
  WindowInfo? _windowToCapture;
  DateTime _lastCaptureTime = DateTime.now();
  Map<String, dynamic>? _lastCaptureResult;

  // Enable/disable performance optimizations
  bool _useDirectBitmap =
      true; // Uses raw bitmap data without PNG encoding for preview
  bool _useCaching = true; // Uses frame caching to reduce processing

  // Tambahkan flag untuk penggunaan GPU
  bool _useGpuAcceleration = true;
  bool get useGpuAcceleration => _useGpuAcceleration;

  void toggleGpuAcceleration() {
    _useGpuAcceleration = !_useGpuAcceleration;
    _lastCaptureResult = null; // Reset cache saat mengubah mode
    print('GPU Acceleration: ${_useGpuAcceleration ? 'Enabled' : 'Disabled'}');
  }

  // Setting untuk performa
  CaptureMethod _captureMethod = CaptureMethod.standard;
  final int _targetFrameIntervalMicros = 16667; // 60 FPS target (1000000/60)
  bool _extremeOptimizationMode = false; // Disable by default

  // Properties untuk tracking window class
  String? _windowClass;

  // Getters
  double get currentFps => _currentFps;
  CaptureMethod get captureMethod => _captureMethod;
  bool get extremeOptimizationMode => _extremeOptimizationMode;
  WindowInfo? get windowToCapture => _windowToCapture;

  // Methods
  void toggleExtremeOptimizationMode() {
    _extremeOptimizationMode = !_extremeOptimizationMode;
    _lastCaptureResult = null; // Clear cached results
  }

  void setCaptureMethod(CaptureMethod method) {
    _captureMethod = method;
  }

  void setWindowToCapture(WindowInfo? window) {
    _windowToCapture = window;
    _windowClass = null;

    // Detect window class to apply specialized capture techniques
    if (window != null && window.hwnd != 0) {
      _windowClass = _getWindowClass(window.hwnd);

      // Auto-select appropriate capture method based on window type
      _autoSelectCaptureMethod(window.title, _windowClass);
    }
  }

  // Helper to get window class name
  String? _getWindowClass(int hwnd) {
    final classNameBuffer = calloc<Uint16>(256).cast<Utf16>();
    final length = GetClassName(hwnd, classNameBuffer, 256);

    String? className;
    if (length > 0) {
      className = classNameBuffer.toDartString();
    }

    calloc.free(classNameBuffer);
    return className;
  }

  // Automatically select the appropriate capture method based on window type
  void _autoSelectCaptureMethod(String windowTitle, String? windowClass) {
    // Check if it's a browser window
    bool isBrowser = false;
    if (windowClass != null) {
      isBrowser =
          windowClass.contains(
            'Chrome_WidgetWin',
          ) || // Chrome, Edge, other Chromium
          windowClass.contains('MozillaWindowClass') || // Firefox
          windowTitle.toLowerCase().contains('microsoft edge') ||
          windowTitle.toLowerCase().contains('google chrome') ||
          windowTitle.toLowerCase().contains('firefox') ||
          windowTitle.toLowerCase().contains('opera') ||
          windowTitle.toLowerCase().contains('brave');
    }

    // Check if it might be a fullscreen application
    bool mightBeFullscreen = false;
    if (windowTitle.toLowerCase().contains('projector') ||
        windowTitle.toLowerCase().contains('fullscreen') ||
        windowTitle.toLowerCase().contains('game') ||
        windowTitle.toLowerCase().contains('obs')) {
      mightBeFullscreen = true;
    }

    // Select capture method
    if (isBrowser || mightBeFullscreen) {
      setCaptureMethod(CaptureMethod.fullscreen);
    } else {
      // For general windows, use PrintWindow as it's more reliable
      setCaptureMethod(CaptureMethod.printWindow);
    }
  }

  // Optimized capture function with better error handling and CPU optimization
  Future<Map<String, dynamic>?> captureWindowWithSize() async {
    if (_windowToCapture == null) return null;

    // Skip capture if window is minimized
    if (IsIconic(_windowToCapture!.hwnd) != 0) {
      return _lastCaptureResult;
    }

    // FPS limiter - Calculate time since last capture
    final now = DateTime.now();
    final elapsed = now.difference(_lastCaptureTime).inMicroseconds;

    // Reuse cached frame if within time threshold and caching is enabled
    if (elapsed < _targetFrameIntervalMicros &&
        _lastCaptureResult != null &&
        _useCaching) {
      return _lastCaptureResult;
    }

    try {
      // Downsample factor normal
      int downsampleFactor = 1;

      // Extreme mode uses more aggressive downsampling
      if (_extremeOptimizationMode) {
        downsampleFactor = 2;
      }

      // Capture with DXGI if GPU acceleration is enabled and available
      Map<String, dynamic>? result;

      if (_useGpuAcceleration) {
        // Try using the true GPU acceleration via DXGI first
        try {
          if (await GpuCaptureService.isSupported()) {
            print('Using true GPU acceleration via DXGI Desktop Duplication');
            result = await GpuCaptureService.captureWindow(
              _windowToCapture!.hwnd,
            );

            // Apply downsampling if needed
            if (result != null && downsampleFactor > 1) {
              result = _downsampleResult(result, downsampleFactor);
            }
          } else {
            result = await _captureWithDirect3DFallback(
              downsampleFactor: downsampleFactor,
            );
          }
        } catch (e) {
          // Fallback to CPU methods if GPU methods fail
          print('GPU capture failed, falling back to CPU: $e');
        }
      }

      // Fallback to standard methods if direct3d capture fails or not enabled
      if (result == null) {
        try {
          switch (_captureMethod) {
            case CaptureMethod.standard:
              result = await _captureWithBitBlt(
                downsampleFactor: downsampleFactor,
              );
              break;
            case CaptureMethod.printWindow:
              result = await _captureWithPrintWindow(
                downsampleFactor: downsampleFactor,
              );
              break;
            case CaptureMethod.fullscreen:
              result = await _captureWithFullscreenApp(
                downsampleFactor: downsampleFactor,
              );
              break;
          }
        } catch (e) {
          // Try other method if primary method fails
          result = await _captureWithBitBlt(downsampleFactor: downsampleFactor);
        }
      }

      _lastCaptureTime = now;

      if (result != null) {
        // Process result and update cache
        _lastCaptureResult = result;

        // Update FPS counter
        _frameCount++;
        if (now.difference(_lastFpsUpdateTime).inMilliseconds > 1000) {
          _currentFps =
              _frameCount *
              1000 /
              now.difference(_lastFpsUpdateTime).inMilliseconds;
          _frameCount = 0;
          _lastFpsUpdateTime = now;
        }
      }

      return result;
    } catch (e) {
      print('Error in captureWindowWithSize: $e');
      return _lastCaptureResult; // Return last result on error
    }
  }

  // Helper method to downsample a capture result
  Map<String, dynamic> _downsampleResult(
    Map<String, dynamic> result,
    int downsampleFactor,
  ) {
    final originalWidth = result['width'] as int;
    final originalHeight = result['height'] as int;
    final originalBytes = result['bytes'] as Uint8List;

    final downsampledWidth = originalWidth ~/ downsampleFactor;
    final downsampledHeight = originalHeight ~/ downsampleFactor;

    // Create a new map with the downsampled values
    final downsampledResult = Map<String, dynamic>.from(result);

    if (result['isDirect'] == true) {
      // Create downsampled image with direct bitmap
      final downsampledSize = downsampledWidth * downsampledHeight * 4;
      final downsampledPixels = Uint8List(downsampledSize);

      // Simple but efficient downsampling
      for (int y = 0; y < downsampledHeight; y++) {
        final srcY = y * downsampleFactor;
        if (srcY >= originalHeight) continue;

        for (int x = 0; x < downsampledWidth; x++) {
          final srcX = x * downsampleFactor;
          if (srcX >= originalWidth) continue;

          final srcOffset = (srcY * originalWidth + srcX) * 4;
          final destOffset = (y * downsampledWidth + x) * 4;

          if (srcOffset + 3 < originalBytes.length &&
              destOffset + 3 < downsampledPixels.length) {
            // Copy RGBA values directly (already in correct format from GPU capture)
            downsampledPixels[destOffset] = originalBytes[srcOffset];
            downsampledPixels[destOffset + 1] = originalBytes[srcOffset + 1];
            downsampledPixels[destOffset + 2] = originalBytes[srcOffset + 2];
            downsampledPixels[destOffset + 3] = originalBytes[srcOffset + 3];
          }
        }
      }

      downsampledResult['bytes'] = downsampledPixels;
      downsampledResult['width'] = downsampledWidth;
      downsampledResult['height'] = downsampledHeight;
    }

    return downsampledResult;
  }

  // Metode untuk Direct3D capture - mengoptimalkan untuk aplikasi yang menggunakan GPU
  Future<Map<String, dynamic>?> _captureWithDirect3DFallback({
    int downsampleFactor = 1,
  }) async {
    int hwnd = _windowToCapture!.hwnd;

    // Check if window is still valid
    if (IsWindow(hwnd) == 0) {
      return null;
    }

    final rect = calloc<RECT>();
    try {
      if (GetWindowRect(hwnd, rect) == 0) {
        return null;
      }

      int width = rect.ref.right - rect.ref.left;
      int height = rect.ref.bottom - rect.ref.top;

      // Check for valid dimensions
      if (width <= 0 || height <= 0 || width > 10000 || height > 10000) {
        return null;
      }

      // Create DC and bitmap
      final hdcScreen = GetDC(0); // DC for entire screen
      if (hdcScreen == 0) {
        return null;
      }

      final hdcMemDC = CreateCompatibleDC(hdcScreen);
      if (hdcMemDC == 0) {
        ReleaseDC(0, hdcScreen);
        return null;
      }

      final hbmScreen = CreateCompatibleBitmap(hdcScreen, width, height);
      if (hbmScreen == 0) {
        DeleteDC(hdcMemDC);
        ReleaseDC(0, hdcScreen);
        return null;
      }

      final hbmOld = SelectObject(hdcMemDC, hbmScreen);

      // Optimization for Direct3D windows:
      // 1. Try PrintWindow with PW_RENDERFULLCONTENT (2) for best quality with Direct3D content
      // 2. Fallback to standard PrintWindow if that fails
      int pwResult = 0;

      // First try with PW_RENDERFULLCONTENT for better Direct3D capture
      pwResult = PrintWindow(hwnd, hdcMemDC, 2);

      // If failed, try with standard PrintWindow
      if (pwResult == 0) {
        pwResult = PrintWindow(hwnd, hdcMemDC, 0);

        // If both methods fail, then return null for fallback to other methods
        if (pwResult == 0) {
          SelectObject(hdcMemDC, hbmOld);
          DeleteObject(hbmScreen);
          DeleteDC(hdcMemDC);
          ReleaseDC(0, hdcScreen);
          return null;
        }
      }

      // Get the bitmap data
      final bmi = calloc<BITMAPINFO>();
      bmi.ref.bmiHeader.biSize = sizeOf<BITMAPINFOHEADER>();
      bmi.ref.bmiHeader.biWidth = width;
      bmi.ref.bmiHeader.biHeight = -height; // Negative for top-down DIB
      bmi.ref.bmiHeader.biPlanes = 1;
      bmi.ref.bmiHeader.biBitCount = 32; // 32-bit BGRA
      bmi.ref.bmiHeader.biCompression = BI_RGB;

      final pixelDataSize = width * height * 4;
      final pixelData = calloc<Uint8>(pixelDataSize);

      // Get bitmap bits
      final dibResult = GetDIBits(
        hdcMemDC,
        hbmScreen,
        0,
        height,
        pixelData,
        bmi,
        DIB_RGB_COLORS,
      );

      if (dibResult == 0) {
        SelectObject(hdcMemDC, hbmOld);
        DeleteObject(hbmScreen);
        DeleteDC(hdcMemDC);
        ReleaseDC(0, hdcScreen);
        calloc.free(bmi);
        calloc.free(pixelData);
        return null;
      }

      // Copy pixels to Dart Uint8List
      final pixels = Uint8List(pixelDataSize);
      for (int i = 0; i < pixelDataSize; i++) {
        pixels[i] = pixelData[i];
      }

      // Clean up resources
      SelectObject(hdcMemDC, hbmOld);
      DeleteObject(hbmScreen);
      DeleteDC(hdcMemDC);
      ReleaseDC(0, hdcScreen);
      calloc.free(bmi);
      calloc.free(pixelData);

      // Process image data
      final result = _processImageData(pixels, width, height, downsampleFactor);

      // Mark result as GPU accelerated mode (though it's a software fallback)
      if (result != null) {
        result['isGpuAccelerated'] = false; // Changed from true to false
        result['captureMethod'] = 'direct3d_fallback';
        result['originalWidth'] = width;
        result['originalHeight'] = height;
      }

      return result;
    } catch (e) {
      print('Error in Direct3D capture: $e');
      return null;
    } finally {
      calloc.free(rect);
    }
  }

  // Simplified BitBlt method focusing on reliability
  Future<Map<String, dynamic>?> _captureWithBitBlt({
    int downsampleFactor = 1,
  }) async {
    int hwnd = _windowToCapture!.hwnd;

    // Check if window is still valid
    if (IsWindow(hwnd) == 0) {
      return null;
    }

    // Get window dimensions
    final rect = calloc<RECT>();
    try {
      if (GetWindowRect(hwnd, rect) == 0) {
        return null;
      }

      int width = rect.ref.right - rect.ref.left;
      int height = rect.ref.bottom - rect.ref.top;

      // Check for valid dimensions
      if (width <= 0 || height <= 0 || width > 10000 || height > 10000) {
        return null;
      }

      // Create HDCs and bitmap
      final hdcWindow = GetDC(hwnd);
      if (hdcWindow == 0) {
        return null;
      }

      final hdcMemDC = CreateCompatibleDC(hdcWindow);
      if (hdcMemDC == 0) {
        ReleaseDC(hwnd, hdcWindow);
        return null;
      }

      final hbmScreen = CreateCompatibleBitmap(hdcWindow, width, height);
      if (hbmScreen == 0) {
        DeleteDC(hdcMemDC);
        ReleaseDC(hwnd, hdcWindow);
        return null;
      }

      final hbmOld = SelectObject(hdcMemDC, hbmScreen);

      // Perform BitBlt
      int blResult = BitBlt(
        hdcMemDC,
        0,
        0,
        width,
        height,
        hdcWindow,
        0,
        0,
        SRCCOPY,
      );

      if (blResult == 0) {
        SelectObject(hdcMemDC, hbmOld);
        DeleteObject(hbmScreen);
        DeleteDC(hdcMemDC);
        ReleaseDC(hwnd, hdcWindow);
        return null;
      }

      // Get the bitmap data
      final bmi = calloc<BITMAPINFO>();
      bmi.ref.bmiHeader.biSize = sizeOf<BITMAPINFOHEADER>();
      bmi.ref.bmiHeader.biWidth = width;
      bmi.ref.bmiHeader.biHeight = -height; // Negative for top-down DIB
      bmi.ref.bmiHeader.biPlanes = 1;
      bmi.ref.bmiHeader.biBitCount = 32; // 32-bit BGRA
      bmi.ref.bmiHeader.biCompression = BI_RGB;

      final pixelDataSize = width * height * 4;
      final pixelData = calloc<Uint8>(pixelDataSize);

      // Get bitmap bits
      final dibResult = GetDIBits(
        hdcMemDC,
        hbmScreen,
        0,
        height,
        pixelData,
        bmi,
        DIB_RGB_COLORS,
      );

      if (dibResult == 0) {
        SelectObject(hdcMemDC, hbmOld);
        DeleteObject(hbmScreen);
        DeleteDC(hdcMemDC);
        ReleaseDC(hwnd, hdcWindow);
        calloc.free(bmi);
        calloc.free(pixelData);
        return null;
      }

      // Copy pixels to Dart Uint8List
      final pixels = Uint8List(pixelDataSize);
      for (int i = 0; i < pixelDataSize; i++) {
        pixels[i] = pixelData[i];
      }

      // Clean up resources
      SelectObject(hdcMemDC, hbmOld);
      DeleteObject(hbmScreen);
      DeleteDC(hdcMemDC);
      ReleaseDC(hwnd, hdcWindow);
      calloc.free(bmi);
      calloc.free(pixelData);

      // Process and return the image data
      return _processImageData(pixels, width, height, downsampleFactor);
    } finally {
      calloc.free(rect);
    }
  }

  // Simplified PrintWindow method
  Future<Map<String, dynamic>?> _captureWithPrintWindow({
    int downsampleFactor = 1,
  }) async {
    int hwnd = _windowToCapture!.hwnd;

    // Check if window is still valid
    if (IsWindow(hwnd) == 0) {
      return null;
    }

    final rect = calloc<RECT>();
    try {
      if (GetWindowRect(hwnd, rect) == 0) {
        return null;
      }

      int width = rect.ref.right - rect.ref.left;
      int height = rect.ref.bottom - rect.ref.top;

      // Check for valid dimensions
      if (width <= 0 || height <= 0 || width > 10000 || height > 10000) {
        return null;
      }

      // Create DC and bitmap
      final hdcScreen = GetDC(0); // Get DC for the entire screen
      if (hdcScreen == 0) {
        return null;
      }

      final hdcMemDC = CreateCompatibleDC(hdcScreen);
      if (hdcMemDC == 0) {
        ReleaseDC(0, hdcScreen);
        return null;
      }

      final hbmScreen = CreateCompatibleBitmap(hdcScreen, width, height);
      if (hbmScreen == 0) {
        DeleteDC(hdcMemDC);
        ReleaseDC(0, hdcScreen);
        return null;
      }

      final hbmOld = SelectObject(hdcMemDC, hbmScreen);

      // Try PrintWindow with PW_RENDERFULLCONTENT flag
      int pwResult = PrintWindow(hwnd, hdcMemDC, 2); // PW_RENDERFULLCONTENT = 2
      if (pwResult == 0) {
        // If that fails, try standard PrintWindow
        pwResult = PrintWindow(hwnd, hdcMemDC, 0);
        if (pwResult == 0) {
          SelectObject(hdcMemDC, hbmOld);
          DeleteObject(hbmScreen);
          DeleteDC(hdcMemDC);
          ReleaseDC(0, hdcScreen);
          return null;
        }
      }

      // Get the bitmap data
      final bmi = calloc<BITMAPINFO>();
      bmi.ref.bmiHeader.biSize = sizeOf<BITMAPINFOHEADER>();
      bmi.ref.bmiHeader.biWidth = width;
      bmi.ref.bmiHeader.biHeight = -height; // Negative for top-down DIB
      bmi.ref.bmiHeader.biPlanes = 1;
      bmi.ref.bmiHeader.biBitCount = 32; // 32-bit BGRA
      bmi.ref.bmiHeader.biCompression = BI_RGB;

      final pixelDataSize = width * height * 4;
      final pixelData = calloc<Uint8>(pixelDataSize);

      // Get bitmap bits
      final dibResult = GetDIBits(
        hdcMemDC,
        hbmScreen,
        0,
        height,
        pixelData,
        bmi,
        DIB_RGB_COLORS,
      );

      if (dibResult == 0) {
        SelectObject(hdcMemDC, hbmOld);
        DeleteObject(hbmScreen);
        DeleteDC(hdcMemDC);
        ReleaseDC(0, hdcScreen);
        calloc.free(bmi);
        calloc.free(pixelData);
        return null;
      }

      // Copy pixels to Dart Uint8List
      final pixels = Uint8List(pixelDataSize);
      for (int i = 0; i < pixelDataSize; i++) {
        pixels[i] = pixelData[i];
      }

      // Clean up resources
      SelectObject(hdcMemDC, hbmOld);
      DeleteObject(hbmScreen);
      DeleteDC(hdcMemDC);
      ReleaseDC(0, hdcScreen);
      calloc.free(bmi);
      calloc.free(pixelData);

      // Process and return the image data
      return _processImageData(pixels, width, height, downsampleFactor);
    } finally {
      calloc.free(rect);
    }
  }

  // Simplified fullscreen method
  Future<Map<String, dynamic>?> _captureWithFullscreenApp({
    int downsampleFactor = 1,
  }) async {
    // For fullscreen apps, use PrintWindow directly
    return await _captureWithPrintWindow(downsampleFactor: downsampleFactor);
  }

  // Helper method to process image data
  Map<String, dynamic>? _processImageData(
    Uint8List pixels,
    int width,
    int height,
    int downsampleFactor,
  ) {
    if (pixels.isEmpty) return null;

    final actualDownsampleFactor = downsampleFactor > 1 ? downsampleFactor : 1;

    // If downsampling is needed
    if (actualDownsampleFactor > 1) {
      final downsampledWidth = width ~/ actualDownsampleFactor;
      final downsampledHeight = height ~/ actualDownsampleFactor;

      if (_useDirectBitmap) {
        // Create downsampled image with direct bitmap
        final downsampledSize = downsampledWidth * downsampledHeight * 4;
        final downsampledPixels = Uint8List(downsampledSize);

        // Simple but efficient downsampling
        for (int y = 0; y < downsampledHeight; y++) {
          final srcY = y * actualDownsampleFactor;
          if (srcY >= height) continue;

          for (int x = 0; x < downsampledWidth; x++) {
            final srcX = x * actualDownsampleFactor;
            if (srcX >= width) continue;

            final srcOffset = (srcY * width + srcX) * 4;
            final destOffset = (y * downsampledWidth + x) * 4;

            if (srcOffset + 3 < pixels.length &&
                destOffset + 3 < downsampledPixels.length) {
              // Copy BGRA values, swapping BR to get RGBA directly
              downsampledPixels[destOffset] = pixels[srcOffset + 2]; // R = B
              downsampledPixels[destOffset + 1] =
                  pixels[srcOffset + 1]; // G = G
              downsampledPixels[destOffset + 2] = pixels[srcOffset]; // B = R
              downsampledPixels[destOffset + 3] =
                  pixels[srcOffset + 3]; // A = A
            }
          }
        }

        return {
          'bytes': downsampledPixels,
          'width': downsampledWidth,
          'height': downsampledHeight,
          'isDirect': true,
          'originalWidth': width,
          'originalHeight': height,
        };
      } else {
        // PNG encoding is much slower but may be needed for compatibility
        try {
          final image = img.Image(
            width: downsampledWidth,
            height: downsampledHeight,
          );
          for (int y = 0; y < downsampledHeight; y++) {
            for (int x = 0; x < downsampledWidth; x++) {
              final srcX = x * actualDownsampleFactor;
              final srcY = y * actualDownsampleFactor;
              if (srcX < width && srcY < height) {
                final srcOffset = (srcY * width + srcX) * 4;
                if (srcOffset + 3 < pixels.length) {
                  final b = pixels[srcOffset];
                  final g = pixels[srcOffset + 1];
                  final r = pixels[srcOffset + 2];
                  final a = pixels[srcOffset + 3];
                  image.setPixel(x, y, img.ColorRgba8(r, g, b, a));
                }
              }
            }
          }

          final pngBytes = Uint8List.fromList(img.encodePng(image));
          return {
            'bytes': pngBytes,
            'width': downsampledWidth,
            'height': downsampledHeight,
            'isDirect': false,
            'originalWidth': width,
            'originalHeight': height,
          };
        } catch (e) {
          print('Error converting to PNG: $e');
          return null;
        }
      }
    } else {
      // Full-size processing
      if (_useDirectBitmap) {
        // Convert BGRA to RGBA in-place for direct usage
        for (int i = 0; i < width * height; i++) {
          final pixelOffset = i * 4;
          // Swap B and R
          final temp = pixels[pixelOffset];
          pixels[pixelOffset] = pixels[pixelOffset + 2];
          pixels[pixelOffset + 2] = temp;
        }

        return {
          'bytes': pixels,
          'width': width,
          'height': height,
          'isDirect': true,
          'originalWidth': width,
          'originalHeight': width,
        };
      } else {
        try {
          final image = img.Image(width: width, height: height);
          for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
              final i = (y * width + x) * 4;
              if (i + 3 < pixels.length) {
                final b = pixels[i];
                final g = pixels[i + 1];
                final r = pixels[i + 2];
                final a = pixels[i + 3];
                image.setPixel(x, y, img.ColorRgba8(r, g, b, a));
              }
            }
          }

          final pngBytes = Uint8List.fromList(img.encodePng(image));
          return {
            'bytes': pngBytes,
            'width': width,
            'height': height,
            'isDirect': false,
            'originalWidth': width,
            'originalHeight': height,
          };
        } catch (e) {
          print('Error converting to PNG: $e');
          return null;
        }
      }
    }
  }

  // Capture full window for photo
  Future<Uint8List?> captureWindow() async {
    // For actual photo capture (not preview), disable performance optimizations
    bool prevUseDirectBitmap = _useDirectBitmap;
    bool prevUseCaching = _useCaching;

    _useDirectBitmap = false;
    _useCaching = false;

    try {
      // Always use downsampleFactor: 1 for full resolution captures
      Map<String, dynamic>? result;

      switch (_captureMethod) {
        case CaptureMethod.standard:
          result = await _captureWithBitBlt(downsampleFactor: 1);
          break;
        case CaptureMethod.printWindow:
          result = await _captureWithPrintWindow(downsampleFactor: 1);
          break;
        case CaptureMethod.fullscreen:
          result = await _captureWithFullscreenApp(downsampleFactor: 1);
          break;
      }

      if (result == null) return null;

      // If result is already in PNG format, return it directly
      if (result['isDirect'] == false) {
        return result['bytes'] as Uint8List;
      }

      // Convert direct bitmap data to PNG for saving
      final width = result['width'] as int;
      final height = result['height'] as int;
      final bytes = result['bytes'] as Uint8List;

      // Create an image from RGBA pixels
      final image = img.Image(width: width, height: height);
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final i = (y * width + x) * 4;
          if (i + 3 < bytes.length) {
            final r = bytes[i];
            final g = bytes[i + 1];
            final b = bytes[i + 2];
            final a = bytes[i + 3];
            image.setPixel(x, y, img.ColorRgba8(r, g, b, a));
          }
        }
      }

      // Encode to PNG with high quality for saving
      return Uint8List.fromList(img.encodePng(image));
    } catch (e) {
      print('Error capturing full-resolution window: $e');
      return null;
    } finally {
      // Restore performance optimization settings
      _useDirectBitmap = prevUseDirectBitmap;
      _useCaching = prevUseCaching;
    }
  }

  // Fungsi static helper untuk mendapatkan daftar window
  static Future<List<WindowInfo>> getWindowsList() async {
    try {
      // Clear previous windows list
      _WindowCollection.clear();

      // Use the static callback function
      final enumWindowsProc = Pointer.fromFunction<EnumWindowsProc>(
        _enumWindowsProc,
        0,
      );

      // Call the Win32 EnumWindows function
      final result = EnumWindows(enumWindowsProc, 0);

      // Create a new list with the collected windows
      final windows = List<WindowInfo>.from(_WindowCollection.windows);

      // Add a special entry for "None" so user can deselect
      windows.insert(0, WindowInfo(hwnd: 0, title: 'Select a window...'));

      return windows;
    } catch (e) {
      print('Error getting windows list: $e');
      return [WindowInfo(hwnd: 0, title: 'Error loading windows')];
    }
  }
}
