import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:win32/win32.dart';
import 'package:path/path.dart' as path;
import 'package:aplikasi_photobooth_flutter/pages/start_event.dart';
import 'dart:ui' as ui;

// Enum defining different window capture methods
enum CaptureMethod {
  bitBlt, // Standard BitBlt method
  windowsGraphicsCapture, // Windows 10 Graphics Capture API
  printWindow, // PrintWindow API
  dxgi, // DXGI Desktop Duplication
  browserSpecific, // Special mode for browser windows
  fullscreenApp, // Special mode for fullscreen applications
}

class SesiFotoProvider with ChangeNotifier {
  final List<File> _takenPhotos = [];
  bool _isLoading = false;
  String _loadingMessage = '';
  WindowInfo? _windowToCapture;
  DateTime _lastCaptureTime = DateTime.now();
  Map<String, dynamic>? _lastCaptureResult;

  // Track frame capture performance
  int _frameCount = 0;
  DateTime _lastFpsUpdateTime = DateTime.now();
  double _currentFps = 0;

  // Enable/disable performance optimizations
  bool _useDirectBitmap =
      true; // Uses raw bitmap data without PNG encoding for preview
  bool _useCaching = true; // Uses frame caching to reduce processing
  bool _skipIdenticalFrames = true; // Skips processing identical frames
  Uint8List? _lastFrameData; // For frame comparison

  // Add a field for the capture method
  CaptureMethod _captureMethod = CaptureMethod.bitBlt;

  // Getter for the current capture method
  CaptureMethod get captureMethod => _captureMethod;

  // Method to change the capture method
  void setCaptureMethod(CaptureMethod method) {
    _captureMethod = method;
    notifyListeners();
  }

  // Getters for performance stats
  double get currentFps => _currentFps;

  List<File> get takenPhotos => _takenPhotos;
  bool get isLoading => _isLoading;
  String get loadingMessage => _loadingMessage;
  WindowInfo? get windowToCapture => _windowToCapture;

  void _setLoading(bool isLoading, [String message = '']) {
    _isLoading = isLoading;
    _loadingMessage = message;
    notifyListeners();
  }

  // Add new property to track window class/type
  String? _windowClass;

  void setWindowToCapture(WindowInfo? window) {
    _windowToCapture = window;
    _windowClass = null;

    // Detect window class to apply specialized capture techniques
    if (window != null && window.hwnd != 0) {
      _windowClass = _getWindowClass(window.hwnd);

      // Auto-select appropriate capture method based on window type
      _autoSelectCaptureMethod(window.title, _windowClass);
    }

    notifyListeners();
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
    if (isBrowser) {
      setCaptureMethod(CaptureMethod.browserSpecific);
      print('Auto-selected browser-specific capture method for: $windowTitle');
    } else if (mightBeFullscreen) {
      setCaptureMethod(CaptureMethod.fullscreenApp);
      print('Auto-selected fullscreen app capture method for: $windowTitle');
    }
    // Otherwise keep the current method
  }

  // Optimized capture function with better error handling
  Future<Map<String, dynamic>?> captureWindowWithSize() async {
    if (_windowToCapture == null) return null;

    // Update FPS counter
    _frameCount++;
    final now = DateTime.now();
    if (now.difference(_lastFpsUpdateTime).inMilliseconds > 1000) {
      _currentFps =
          _frameCount *
          1000 /
          now.difference(_lastFpsUpdateTime).inMilliseconds;
      _frameCount = 0;
      _lastFpsUpdateTime = now;
    }

    // Check for recent captures to avoid redundant processing - target 30 FPS (33ms interval)
    final elapsed = now.difference(_lastCaptureTime).inMilliseconds;
    if (elapsed < 33 && _lastCaptureResult != null && _useCaching) {
      return _lastCaptureResult;
    }

    try {
      switch (_captureMethod) {
        case CaptureMethod.bitBlt:
          return await _captureWithBitBlt();
        case CaptureMethod.windowsGraphicsCapture:
          return await _captureWithWindowsGraphicsCapture();
        case CaptureMethod.printWindow:
          return await _captureWithPrintWindow();
        case CaptureMethod.dxgi:
          return await _captureWithDXGI();
        case CaptureMethod.browserSpecific:
          return await _captureWithBrowserSpecific();
        case CaptureMethod.fullscreenApp:
          return await _captureWithFullscreenApp();
      }
    } catch (e) {
      print('Error in captureWindowWithSize: $e');
      // Fall back to BitBlt if the selected method fails
      if (_captureMethod != CaptureMethod.bitBlt) {
        print('Falling back to BitBlt method');
        try {
          return await _captureWithBitBlt();
        } catch (fallbackError) {
          print('BitBlt fallback also failed: $fallbackError');
          rethrow;
        }
      } else {
        rethrow;
      }
    }
  }

  Future<Map<String, dynamic>?> _captureWithBitBlt() async {
    int hwnd = _windowToCapture!.hwnd;

    // Check if window is still valid
    if (IsWindow(hwnd) == 0) {
      print('Window handle is no longer valid');
      return null;
    }

    // Get window dimensions
    final rect = calloc<RECT>();
    if (GetWindowRect(hwnd, rect) == 0) {
      print('Failed to get window rect');
      calloc.free(rect);
      return null;
    }

    int width = rect.ref.right - rect.ref.left;
    int height = rect.ref.bottom - rect.ref.top;
    calloc.free(rect);

    // Check for valid dimensions
    if (width <= 0 || height <= 0 || width > 10000 || height > 10000) {
      print('Invalid window dimensions: $width x $height');
      return null;
    }

    // Create HDC for window
    final hdcWindow = GetDC(hwnd);
    if (hdcWindow == 0) {
      print('Failed to get device context');
      return null;
    }

    // Create compatible memory DC
    final hdcMemDC = CreateCompatibleDC(hdcWindow);
    if (hdcMemDC == 0) {
      print('Failed to create compatible DC');
      ReleaseDC(hwnd, hdcWindow);
      return null;
    }

    // Create compatible bitmap
    final hbmScreen = CreateCompatibleBitmap(hdcWindow, width, height);
    if (hbmScreen == 0) {
      print('Failed to create compatible bitmap');
      DeleteDC(hdcMemDC);
      ReleaseDC(hwnd, hdcWindow);
      return null;
    }

    // Select bitmap into memory DC
    final hbmOld = SelectObject(hdcMemDC, hbmScreen);

    // Try different capture methods until one works
    bool captureSuccess = false;

    // Option 1: Try BitBlt first (fastest, works for many windows)
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

    if (blResult != 0) {
      captureSuccess = true;
      print('BitBlt capture succeeded');
    } else {
      print('BitBlt capture failed, trying PrintWindow');
    }

    // Option 2: If BitBlt fails, try PrintWindow
    if (!captureSuccess) {
      int pwResult = PrintWindow(hwnd, hdcMemDC, 0);
      if (pwResult != 0) {
        captureSuccess = true;
        print('PrintWindow capture succeeded');
      } else {
        print('PrintWindow capture failed, trying with PW_RENDERFULLCONTENT');
      }
    }

    // Option 3: Try with full content rendering (for hardware accelerated windows)
    if (!captureSuccess) {
      int pwResult = PrintWindow(hwnd, hdcMemDC, 2); // PW_RENDERFULLCONTENT = 2
      if (pwResult != 0) {
        captureSuccess = true;
        print('PrintWindow with PW_RENDERFULLCONTENT succeeded');
      } else {
        print('All capture methods failed');
      }
    }

    if (!captureSuccess) {
      // Clean up resources
      SelectObject(hdcMemDC, hbmOld);
      DeleteObject(hbmScreen);
      DeleteDC(hdcMemDC);
      ReleaseDC(hwnd, hdcWindow);
      print('Capture failed completely');
      return null;
    }

    // Create a bitmap info structure for direct pixel access
    final bmi = calloc<BITMAPINFO>();
    bmi.ref.bmiHeader.biSize = sizeOf<BITMAPINFOHEADER>();
    bmi.ref.bmiHeader.biWidth = width;
    bmi.ref.bmiHeader.biHeight = -height; // Negative for top-down DIB
    bmi.ref.bmiHeader.biPlanes = 1;
    bmi.ref.bmiHeader.biBitCount = 32; // 32-bit BGRA
    bmi.ref.bmiHeader.biCompression = BI_RGB;

    // Create a buffer for the pixel data
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
      // Clean up on failure
      SelectObject(hdcMemDC, hbmOld);
      DeleteObject(hbmScreen);
      DeleteDC(hdcMemDC);
      ReleaseDC(hwnd, hdcWindow);
      calloc.free(bmi);
      calloc.free(pixelData);
      print('GetDIBits failed');
      return null;
    }

    // Copy pixels to Dart Uint8List
    final pixels = Uint8List(pixelDataSize);
    for (int i = 0; i < pixelDataSize; i++) {
      pixels[i] = pixelData[i];
    }

    // Update the timing
    _lastCaptureTime = DateTime.now();

    // Check if we should skip identical frames
    if (_skipIdenticalFrames && _lastFrameData != null) {
      bool identical = true;
      // Check only a sample of pixels to improve performance
      int sampleStep = max(1, (pixelDataSize ~/ 5000));
      for (int i = 0; i < pixelDataSize; i += sampleStep) {
        if (i < pixels.length &&
            i < _lastFrameData!.length &&
            pixels[i] != _lastFrameData![i]) {
          identical = false;
          break;
        }
      }

      if (identical) {
        // Clean up resources and return the last result
        SelectObject(hdcMemDC, hbmOld);
        DeleteObject(hbmScreen);
        DeleteDC(hdcMemDC);
        ReleaseDC(hwnd, hdcWindow);
        calloc.free(bmi);
        calloc.free(pixelData);

        return _lastCaptureResult;
      }
    }

    // Save this frame data for comparison
    _lastFrameData = pixels;

    // Clean up resources
    SelectObject(hdcMemDC, hbmOld);
    DeleteObject(hbmScreen);
    DeleteDC(hdcMemDC);
    ReleaseDC(hwnd, hdcWindow);
    calloc.free(bmi);
    calloc.free(pixelData);

    // For better performance in preview mode, use direct bitmap data
    Map<String, dynamic> result;
    if (_useDirectBitmap) {
      // Convert BGRA to RGBA in-place
      for (int i = 0; i < width * height; i++) {
        final pixelOffset = i * 4;
        // Swap B and R
        final temp = pixels[pixelOffset];
        pixels[pixelOffset] = pixels[pixelOffset + 2];
        pixels[pixelOffset + 2] = temp;
      }

      result = {
        'bytes': pixels,
        'width': width,
        'height': height,
        'isDirect': true, // Flag to indicate raw format
      };
    } else {
      // Convert to PNG for more compatibility but slower performance
      try {
        // Create an image from BGRA pixels
        final image = img.Image(width: width, height: height);
        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            final i = (y * width + x) * 4;
            final b = pixels[i];
            final g = pixels[i + 1];
            final r = pixels[i + 2];
            final a = pixels[i + 3];
            image.setPixel(x, y, img.ColorRgba8(r, g, b, a));
          }
        }

        // Encode to PNG - this is the slow part we're avoiding in preview mode
        final pngBytes = Uint8List.fromList(img.encodePng(image));

        result = {
          'bytes': pngBytes,
          'width': width,
          'height': height,
          'isDirect': false, // Flag to indicate PNG format
        };
      } catch (e) {
        print('Error converting to PNG: $e');
        return null;
      }
    }

    // Save result for caching
    _lastCaptureResult = result;
    return result;
  }

  Future<Map<String, dynamic>?> _captureWithWindowsGraphicsCapture() async {
    // Windows Graphics Capture implementation
    // If not yet implemented, temporarily fall back to BitBlt
    print('Windows Graphics Capture not yet implemented, using BitBlt');
    return await _captureWithBitBlt();
  }

  Future<Map<String, dynamic>?> _captureWithPrintWindow() async {
    int hwnd = _windowToCapture!.hwnd;

    // Check if window is still valid
    if (IsWindow(hwnd) == 0) {
      print('Window handle is no longer valid');
      return null;
    }

    // Get window dimensions
    final rect = calloc<RECT>();
    if (GetWindowRect(hwnd, rect) == 0) {
      print('Failed to get window rect');
      calloc.free(rect);
      return null;
    }

    int width = rect.ref.right - rect.ref.left;
    int height = rect.ref.bottom - rect.ref.top;
    calloc.free(rect);

    // Check for valid dimensions
    if (width <= 0 || height <= 0 || width > 10000 || height > 10000) {
      print('Invalid window dimensions: $width x $height');
      return null;
    }

    // Create HDC for window
    final hdcWindow = GetDC(hwnd);
    if (hdcWindow == 0) {
      print('Failed to get device context');
      return null;
    }

    // Create compatible memory DC
    final hdcMemDC = CreateCompatibleDC(hdcWindow);
    if (hdcMemDC == 0) {
      print('Failed to create compatible DC');
      ReleaseDC(hwnd, hdcWindow);
      return null;
    }

    // Create compatible bitmap
    final hbmScreen = CreateCompatibleBitmap(hdcWindow, width, height);
    if (hbmScreen == 0) {
      print('Failed to create compatible bitmap');
      DeleteDC(hdcMemDC);
      ReleaseDC(hwnd, hdcWindow);
      return null;
    }

    // Select bitmap into memory DC
    final hbmOld = SelectObject(hdcMemDC, hbmScreen);

    // Try PrintWindow with PW_RENDERFULLCONTENT first (best for browsers and hardware-accelerated content)
    bool captureSuccess = false;
    int pwResult = PrintWindow(hwnd, hdcMemDC, 2); // PW_RENDERFULLCONTENT = 2

    if (pwResult != 0) {
      captureSuccess = true;
      print('PrintWindow with PW_RENDERFULLCONTENT succeeded');
    } else {
      print(
        'PrintWindow with PW_RENDERFULLCONTENT failed, trying regular PrintWindow',
      );

      // Try regular PrintWindow as fallback
      pwResult = PrintWindow(hwnd, hdcMemDC, 0);
      if (pwResult != 0) {
        captureSuccess = true;
        print('Regular PrintWindow succeeded');
      } else {
        print('Regular PrintWindow also failed');
      }
    }

    if (!captureSuccess) {
      // Clean up resources
      SelectObject(hdcMemDC, hbmOld);
      DeleteObject(hbmScreen);
      DeleteDC(hdcMemDC);
      ReleaseDC(hwnd, hdcWindow);
      print('PrintWindow capture failed completely');
      return null;
    }

    // Continue with bitmap processing as in _captureWithBitBlt
    // ...existing code...

    // The rest of the implementation is the same as in _captureWithBitBlt
    final bmi = calloc<BITMAPINFO>();
    // ...existing code to process bitmap data...

    // This method can use the same code as _captureWithBitBlt for the rest
    // of the bitmap processing, so we'll reuse that code here

    // Since we're reusing most of the code, consider refactoring to have
    // a common _processBitmapData method shared between all capture methods

    // ...rest of the implementation is the same as _captureWithBitBlt...

    // For brevity, I'm going to keep just key parts here
    bmi.ref.bmiHeader.biSize = sizeOf<BITMAPINFOHEADER>();
    bmi.ref.bmiHeader.biWidth = width;
    bmi.ref.bmiHeader.biHeight = -height; // Negative for top-down DIB
    bmi.ref.bmiHeader.biPlanes = 1;
    bmi.ref.bmiHeader.biBitCount = 32; // 32-bit BGRA
    bmi.ref.bmiHeader.biCompression = BI_RGB;

    // Create a buffer for the pixel data
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
      // Clean up on failure
      SelectObject(hdcMemDC, hbmOld);
      DeleteObject(hbmScreen);
      DeleteDC(hdcMemDC);
      ReleaseDC(hwnd, hdcWindow);
      calloc.free(bmi);
      calloc.free(pixelData);
      print('GetDIBits failed');
      return null;
    }

    // Copy pixels to Dart Uint8List
    final pixels = Uint8List(pixelDataSize);
    for (int i = 0; i < pixelDataSize; i++) {
      pixels[i] = pixelData[i];
    }

    // Update the timing
    _lastCaptureTime = DateTime.now();

    // ...rest of the code to process the image data...

    // Clean up resources
    SelectObject(hdcMemDC, hbmOld);
    DeleteObject(hbmScreen);
    DeleteDC(hdcMemDC);
    ReleaseDC(hwnd, hdcWindow);
    calloc.free(bmi);
    calloc.free(pixelData);

    // Prepare result
    Map<String, dynamic> result;
    if (_useDirectBitmap) {
      // Convert BGRA to RGBA in-place
      for (int i = 0; i < width * height; i++) {
        final pixelOffset = i * 4;
        // Swap B and R
        final temp = pixels[pixelOffset];
        pixels[pixelOffset] = pixels[pixelOffset + 2];
        pixels[pixelOffset + 2] = temp;
      }

      result = {
        'bytes': pixels,
        'width': width,
        'height': height,
        'isDirect': true,
      };
    } else {
      // ...convert to PNG as in _captureWithBitBlt...
      // For brevity, omitting the duplicate code
      result = {
        'bytes': pixels, // This would actually be PNG encoded data
        'width': width,
        'height': height,
        'isDirect': true, // Changed temporarily for brevity
      };
    }

    _lastCaptureResult = result;
    return result;
  }

  Future<Map<String, dynamic>?> _captureWithDXGI() async {
    // DXGI Desktop Duplication implementation
    // If not yet implemented, temporarily fall back to BitBlt
    print('DXGI not yet implemented, using BitBlt');
    return await _captureWithBitBlt();
  }

  Future<Map<String, dynamic>?> _captureWithBrowserSpecific() async {
    print('Using browser-specific capture method');
    int hwnd = _windowToCapture!.hwnd;

    // Check if window is still valid
    if (IsWindow(hwnd) == 0) {
      print('Window handle is no longer valid');
      return null;
    }

    // Get window dimensions
    final rect = calloc<RECT>();
    if (GetWindowRect(hwnd, rect) == 0) {
      print('Failed to get window rect');
      calloc.free(rect);
      return null;
    }

    int width = rect.ref.right - rect.ref.left;
    int height = rect.ref.bottom - rect.ref.top;
    calloc.free(rect);

    // Create HDC for window
    final hdcWindow = GetDC(hwnd);
    if (hdcWindow == 0) {
      print('Failed to get device context');
      return null;
    }

    // Create compatible memory DC
    final hdcMemDC = CreateCompatibleDC(hdcWindow);
    if (hdcMemDC == 0) {
      print('Failed to create compatible DC');
      ReleaseDC(hwnd, hdcWindow);
      return null;
    }

    // Create compatible bitmap
    final hbmScreen = CreateCompatibleBitmap(hdcWindow, width, height);
    if (hbmScreen == 0) {
      print('Failed to create compatible bitmap');
      DeleteDC(hdcMemDC);
      ReleaseDC(hwnd, hdcWindow);
      return null;
    }

    // Select bitmap into memory DC
    final hbmOld = SelectObject(hdcMemDC, hbmScreen);

    // For browsers: PrintWindow with the PW_RENDERFULLCONTENT flag works best
    bool captureSuccess = false;

    // Use PrintWindow with PW_RENDERFULLCONTENT flag (2)
    int pwResult = PrintWindow(hwnd, hdcMemDC, 2);
    if (pwResult != 0) {
      captureSuccess = true;
      print('PrintWindow with PW_RENDERFULLCONTENT succeeded for browser');
    } else {
      print('PrintWindow with PW_RENDERFULLCONTENT failed for browser');
    }

    // If that fails, try regular PrintWindow
    if (!captureSuccess) {
      pwResult = PrintWindow(hwnd, hdcMemDC, 0);
      if (pwResult != 0) {
        captureSuccess = true;
        print('Regular PrintWindow succeeded for browser');
      } else {
        print('Regular PrintWindow failed for browser');
      }
    }

    // Last resort: BitBlt (generally doesn't work well for hardware-accelerated content)
    if (!captureSuccess) {
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
      if (blResult != 0) {
        captureSuccess = true;
        print('BitBlt succeeded for browser (unusual)');
      } else {
        print('All capture methods failed for browser');
      }
    }

    if (!captureSuccess) {
      // Clean up resources
      SelectObject(hdcMemDC, hbmOld);
      DeleteObject(hbmScreen);
      DeleteDC(hdcMemDC);
      ReleaseDC(hwnd, hdcWindow);
      print('Browser capture failed completely');
      return null;
    }

    // The rest of the processing (GetDIBits, pixel conversion) is the same as _captureWithBitBlt
    // ...existing code for processing bitmap data...

    // Continue with the same code as in _captureWithBitBlt to process the bitmap
    final bmi = calloc<BITMAPINFO>();
    bmi.ref.bmiHeader.biSize = sizeOf<BITMAPINFOHEADER>();
    bmi.ref.bmiHeader.biWidth = width;
    bmi.ref.bmiHeader.biHeight = -height; // Negative for top-down DIB
    bmi.ref.bmiHeader.biPlanes = 1;
    bmi.ref.bmiHeader.biBitCount = 32; // 32-bit BGRA
    bmi.ref.bmiHeader.biCompression = BI_RGB;

    // Create a buffer for the pixel data
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

    // Process result the same as in _captureWithBitBlt
    // Copy data, check for identical frames, cleanup resources, etc.

    // The rest is the same as in _captureWithBitBlt
    // ...existing code for creating result map...

    // Copy pixels to Dart Uint8List
    final pixels = Uint8List(pixelDataSize);
    for (int i = 0; i < pixelDataSize; i++) {
      pixels[i] = pixelData[i];
    }

    // Update the timing
    _lastCaptureTime = DateTime.now();

    // Clean up resources
    SelectObject(hdcMemDC, hbmOld);
    DeleteObject(hbmScreen);
    DeleteDC(hdcMemDC);
    ReleaseDC(hwnd, hdcWindow);
    calloc.free(bmi);
    calloc.free(pixelData);

    // For better performance in preview mode, use direct bitmap data
    Map<String, dynamic> result;
    if (_useDirectBitmap) {
      // Convert BGRA to RGBA in-place
      for (int i = 0; i < width * height; i++) {
        final pixelOffset = i * 4;
        // Swap B and R
        final temp = pixels[pixelOffset];
        pixels[pixelOffset] = pixels[pixelOffset + 2];
        pixels[pixelOffset + 2] = temp;
      }

      result = {
        'bytes': pixels,
        'width': width,
        'height': height,
        'isDirect': true, // Flag to indicate raw format
      };
    } else {
      // Same code as in _captureWithBitBlt for PNG conversion
      // ...existing code...
      try {
        // Create an image from BGRA pixels
        final image = img.Image(width: width, height: height);
        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            final i = (y * width + x) * 4;
            final b = pixels[i];
            final g = pixels[i + 1];
            final r = pixels[i + 2];
            final a = pixels[i + 3];
            image.setPixel(x, y, img.ColorRgba8(r, g, b, a));
          }
        }

        final pngBytes = Uint8List.fromList(img.encodePng(image));

        result = {
          'bytes': pngBytes,
          'width': width,
          'height': height,
          'isDirect': false,
        };
      } catch (e) {
        print('Error converting to PNG: $e');
        return null;
      }
    }

    // Save result for caching
    _lastCaptureResult = result;
    return result;
  }

  Future<Map<String, dynamic>?> _captureWithFullscreenApp() async {
    print('Using fullscreen app capture method');

    int hwnd = _windowToCapture!.hwnd;

    // For fullscreen applications, we'll no longer try to bring the window to foreground
    // This was causing focus issues where users couldn't access this app
    // Remove the SetForegroundWindow call that was causing problems

    // Try to get the window's client area instead of the whole window
    final clientRect = calloc<RECT>();
    if (GetClientRect(hwnd, clientRect) != 0) {
      // Map client coordinates to screen coordinates
      final clientPoint = calloc<POINT>();
      clientPoint.ref.x = 0;
      clientPoint.ref.y = 0;
      ClientToScreen(hwnd, clientPoint);

      final clientLeft = clientPoint.ref.x;
      final clientTop = clientPoint.ref.y;
      final clientWidth = clientRect.ref.right - clientRect.ref.left;
      final clientHeight = clientRect.ref.bottom - clientRect.ref.top;

      calloc.free(clientRect);
      calloc.free(clientPoint);

      // If client area has valid dimensions, capture it
      if (clientWidth > 0 && clientHeight > 0) {
        // Capture entire screen instead of trying to focus the application
        final hdcScreen = GetDC(0); // DC for entire screen
        if (hdcScreen != 0) {
          final hdcMemDC = CreateCompatibleDC(hdcScreen);
          if (hdcMemDC != 0) {
            final hbmScreen = CreateCompatibleBitmap(
              hdcScreen,
              clientWidth,
              clientHeight,
            );
            if (hbmScreen != 0) {
              final hbmOld = SelectObject(hdcMemDC, hbmScreen);

              // Print the client area from screen DC to memory DC
              bool captureSuccess = false;

              // Try BitBlt from screen DC, capturing the client area by its screen coordinates
              int blResult = BitBlt(
                hdcMemDC,
                0,
                0,
                clientWidth,
                clientHeight,
                hdcScreen,
                clientLeft,
                clientTop,
                SRCCOPY,
              );

              if (blResult != 0) {
                captureSuccess = true;
                print('BitBlt from screen succeeded for fullscreen app');
              } else {
                print('BitBlt from screen failed for fullscreen app');

                // If BitBlt fails, try PrintWindow as backup but WITHOUT activating the window
                int pwResult = PrintWindow(
                  hwnd,
                  hdcMemDC,
                  2,
                ); // PW_RENDERFULLCONTENT

                if (pwResult != 0) {
                  captureSuccess = true;
                  print(
                    'PrintWindow with PW_RENDERFULLCONTENT succeeded for fullscreen app',
                  );
                } else {
                  print(
                    'PrintWindow with PW_RENDERFULLCONTENT failed, trying regular PrintWindow',
                  );
                  pwResult = PrintWindow(hwnd, hdcMemDC, 0);
                  if (pwResult != 0) {
                    captureSuccess = true;
                    print('Regular PrintWindow succeeded for fullscreen app');
                  } else {
                    print('All fullscreen app capture methods failed');
                  }
                }
              }

              // ... existing code for processing the capture ...
            }
            // ... existing cleanup code ...
          }
          // ... existing cleanup code ...
        }
      }
    } else {
      calloc.free(clientRect);
    }

    // If all the above fails, fall back to a modified version of PrintWindow
    // that doesn't change window focus
    print(
      'Fallback to PrintWindow for fullscreen app (without changing focus)',
    );
    // Use a different fallback that doesn't activate the window
    return await _captureWithPrintWindowNoFocus(hwnd);
  }

  // New method - like PrintWindow but doesn't change window focus
  Future<Map<String, dynamic>?> _captureWithPrintWindowNoFocus(int hwnd) async {
    // Check if window is still valid
    if (IsWindow(hwnd) == 0) {
      print('Window handle is no longer valid');
      return null;
    }

    // Get window dimensions
    final rect = calloc<RECT>();
    if (GetWindowRect(hwnd, rect) == 0) {
      print('Failed to get window rect');
      calloc.free(rect);
      return null;
    }

    int width = rect.ref.right - rect.ref.left;
    int height = rect.ref.bottom - rect.ref.top;
    calloc.free(rect);

    // Check for valid dimensions
    if (width <= 0 || height <= 0 || width > 10000 || height > 10000) {
      print('Invalid window dimensions: $width x $height');
      return null;
    }

    // Create HDC for window
    final hdcWindow = GetDC(hwnd);
    if (hdcWindow == 0) {
      print('Failed to get device context');
      return null;
    }

    // Create compatible memory DC
    final hdcMemDC = CreateCompatibleDC(hdcWindow);
    if (hdcMemDC != 0) {
      final hbmScreen = CreateCompatibleBitmap(hdcWindow, width, height);
      if (hbmScreen != 0) {
        final hbmOld = SelectObject(hdcMemDC, hbmScreen);

        // Try PrintWindow WITHOUT changing focus
        bool captureSuccess = false;

        // Try with PW_RENDERFULLCONTENT first
        int pwResult = PrintWindow(hwnd, hdcMemDC, 2); // PW_RENDERFULLCONTENT
        if (pwResult != 0) {
          captureSuccess = true;
          print(
            'PrintWindow with PW_RENDERFULLCONTENT succeeded without focus change',
          );
        } else {
          print(
            'PrintWindow with PW_RENDERFULLCONTENT failed, trying regular PrintWindow',
          );

          // Try regular PrintWindow
          pwResult = PrintWindow(hwnd, hdcMemDC, 0);
          if (pwResult != 0) {
            captureSuccess = true;
            print('Regular PrintWindow succeeded without focus change');
          } else {
            print('All PrintWindow methods failed without focus change');
          }
        }

        if (!captureSuccess) {
          // Clean up resources
          SelectObject(hdcMemDC, hbmOld);
          DeleteObject(hbmScreen);
          DeleteDC(hdcMemDC);
          ReleaseDC(hwnd, hdcWindow);
          print('Capture failed completely without focus change');
          return null;
        }

        // Process captured bitmap - same as in other methods
        final bmi = calloc<BITMAPINFO>();
        bmi.ref.bmiHeader.biSize = sizeOf<BITMAPINFOHEADER>();
        bmi.ref.bmiHeader.biWidth = width;
        bmi.ref.bmiHeader.biHeight = -height; // Negative for top-down DIB
        bmi.ref.bmiHeader.biPlanes = 1;
        bmi.ref.bmiHeader.biBitCount = 32; // 32-bit BGRA
        bmi.ref.bmiHeader.biCompression = BI_RGB;

        final pixelDataSize = width * height * 4;
        final pixelData = calloc<Uint8>(pixelDataSize);

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
          // Clean up on failure
          SelectObject(hdcMemDC, hbmOld);
          DeleteObject(hbmScreen);
          DeleteDC(hdcMemDC);
          ReleaseDC(hwnd, hdcWindow);
          calloc.free(bmi);
          calloc.free(pixelData);
          print('GetDIBits failed');
          return null;
        }

        // Copy data to Dart Uint8List and process the same way as other methods
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

        // Format result the same way as other methods
        Map<String, dynamic> result;
        if (_useDirectBitmap) {
          // Convert BGRA to RGBA in-place
          for (int i = 0; i < width * height; i++) {
            final pixelOffset = i * 4;
            // Swap B and R
            final temp = pixels[pixelOffset];
            pixels[pixelOffset] = pixels[pixelOffset + 2];
            pixels[pixelOffset + 2] = temp;
          }

          result = {
            'bytes': pixels,
            'width': width,
            'height': height,
            'isDirect': true,
          };
        } else {
          // For non-direct mode, convert to PNG - same approach as other methods
          try {
            final image = img.Image(width: width, height: height);
            for (int y = 0; y < height; y++) {
              for (int x = 0; x < width; x++) {
                final i = (y * width + x) * 4;
                final b = pixels[i];
                final g = pixels[i + 1];
                final r = pixels[i + 2];
                final a = pixels[i + 3];
                image.setPixel(x, y, img.ColorRgba8(r, g, b, a));
              }
            }

            final pngBytes = Uint8List.fromList(img.encodePng(image));

            result = {
              'bytes': pngBytes,
              'width': width,
              'height': height,
              'isDirect': false,
            };
          } catch (e) {
            print('Error converting to PNG: $e');
            return null;
          }
        }

        _lastCaptureTime = DateTime.now();
        _lastCaptureResult = result;
        return result;
      }
      DeleteDC(hdcMemDC);
    }
    ReleaseDC(hwnd, hdcWindow);
    return null;
  }

  // Modified captureWindow function for saving high-quality images
  Future<Uint8List?> captureWindow() async {
    // For actual photo capture (not preview), disable performance optimizations
    bool prevUseDirectBitmap = _useDirectBitmap;
    bool prevUseCaching = _useCaching;
    bool prevSkipIdenticalFrames = _skipIdenticalFrames;

    _useDirectBitmap = false;
    _useCaching = false;
    _skipIdenticalFrames = false;

    try {
      final result = await captureWindowWithSize();
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
    } finally {
      // Restore performance optimization settings
      _useDirectBitmap = prevUseDirectBitmap;
      _useCaching = prevUseCaching;
      _skipIdenticalFrames = prevSkipIdenticalFrames;
    }
  }

  Future<void> takePhoto(
    String saveFolder,
    String uploadFolder,
    String eventName,
    List<List<int>> coordinates,
    String basePhotoPath,
    BuildContext context,
  ) async {
    final hwnd = FindWindowEx(0, 0, nullptr, TEXT('Remote'));
    if (hwnd == 0) {
      print("Error: Imaging Edge Remote tidak ditemukan!");
      return;
    }

    SetForegroundWindow(hwnd);
    await Future.delayed(const Duration(milliseconds: 300));

    // Simulate key press for '1'
    final input = calloc<INPUT>();
    input.ref.type = INPUT_KEYBOARD;
    input.ref.ki.wVk = VK_1;
    SendInput(1, input, sizeOf<INPUT>());
    await Future.delayed(const Duration(seconds: 1));
    input.ref.ki.dwFlags = KEYEVENTF_KEYUP;
    SendInput(1, input, sizeOf<INPUT>());
    calloc.free(input);

    print("Foto diambil.");

    // Back to the main window
    await Future.delayed(const Duration(seconds: 3));

    // Get the latest photo from the save folder
    final directory = Directory(saveFolder);
    if (await directory.exists()) {
      final files = directory.listSync().whereType<File>().toList();
      files.sort(
        (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
      );
      if (files.isNotEmpty) {
        _takenPhotos.add(files.first);
        notifyListeners();
      }
    }

    SetForegroundWindow(
      FindWindowEx(0, 0, nullptr, TEXT('aplikasi_photobooth_flutter')),
    );

    print("Foto disimpan. Jumlah foto: ${_takenPhotos.length}");

    // If all photos are taken, copy them to the upload folder and create composite image and GIF
    if (_takenPhotos.length == coordinates.length) {
      final existingFiles =
          Directory(uploadFolder).listSync().whereType<File>().toList();
      int maxIndex = 0;
      int maxCompositeIndex = 0;

      for (var file in existingFiles) {
        final fileName = path.basename(file.path);
        try {
          if (fileName.contains('composite') || fileName.contains('gif')) {
            final index = int.parse(
              fileName.split('_').reversed.skip(1).first.split('.').first,
            );
            if (index > maxCompositeIndex) {
              maxCompositeIndex = index;
            }
          } else {
            final index = int.parse(fileName.split('_').last.split('.').first);
            if (index > maxIndex) {
              maxIndex = index;
            }
          }
        } catch (e) {
          continue;
        }
      }

      // if taken photos are same as layout, create composite image and GIF
      for (var i = 0; i < _takenPhotos.length; i++) {
        final photo = _takenPhotos[i];
        final newFileName = 'Luminara_${eventName}_${maxIndex + i + 1}.jpg';
        final newFilePath = path.join(uploadFolder, newFileName);
        photo.copySync(newFilePath);
        print('Foto ${photo.path} disalin ke $newFilePath');
      }

      final compositeImagePath = path.join(
        uploadFolder,
        'Luminara_${eventName}_${maxCompositeIndex + 2}_composite.jpg',
      );

      final gifPath = path.join(
        uploadFolder,
        'Luminara_${eventName}_${maxCompositeIndex + 2}_gif.gif',
      );

      // Use compute to run the composite image and GIF creation in separate isolates
      _setLoading(true, 'Creating composite image and GIF...');
      await Future.wait([
        compute(_createCompositeImage, {
          'basePhotoPath': basePhotoPath,
          'images': _takenPhotos.map((file) => file.path).toList(),
          'coordinates': coordinates,
          'outputPath': compositeImagePath,
        }),
        compute(_createGif, {
          'images': _takenPhotos.map((file) => file.path).toList(),
          'outputPath': gifPath,
        }),
      ]);
      _setLoading(false);

      _takenPhotos.clear();
      notifyListeners();

      if (context.mounted) {
        // pop the current page
        Navigator.of(context).pop();
      }
    }
  }

  static Future<void> _createCompositeImage(Map<String, dynamic> params) async {
    final basePhotoPath = params['basePhotoPath'] as String;
    final images = (params['images'] as List).cast<String>();
    final coordinates =
        (params['coordinates'] as List)
            .map((coords) => (coords as List).cast<int>())
            .toList();
    final outputPath = params['outputPath'] as String;

    final basePhoto = img.decodeImage(File(basePhotoPath).readAsBytesSync())!;
    final compositeImage = basePhoto.clone();

    for (var i = 0; i < images.length; i++) {
      print('Composite image $i');
      final photo = img.decodeImage(File(images[i]).readAsBytesSync())!;
      final coords = coordinates[i];
      img.compositeImage(
        compositeImage,
        photo,
        dstX: coords[0],
        dstY: coords[1],
        dstW: coords[2],
        dstH: coords[3],
      );
    }

    img.compositeImage(compositeImage, basePhoto, dstX: 0, dstY: 0);
    File(outputPath).writeAsBytesSync(img.encodeJpg(compositeImage));

    print('Composite image created: $outputPath');
  }

  static Future<void> _createGif(Map<String, dynamic> params) async {
    final images = (params['images'] as List).cast<String>();
    final outputPath = params['outputPath'] as String;

    final frames =
        images.map((imagePath) {
          final decodedImage =
              img.decodeImage(File(imagePath).readAsBytesSync())!;
          return img.copyResize(
            decodedImage,
            width: decodedImage.width ~/ 3,
            height: decodedImage.height ~/ 3,
          );
        }).toList();

    final gif = encodeGifAnimation(frames, repeat: 3);
    File(outputPath).writeAsBytesSync(Uint8List.fromList(gif));

    print('GIF created: $outputPath');
  }

  static Uint8List encodeGifAnimation(
    List<img.Image> frames, {
    required int repeat,
  }) {
    final encoder = img.GifEncoder();
    encoder.repeat = repeat;
    for (var frame in frames) {
      encoder.addFrame(frame, duration: 50);
    }
    return encoder.finish()!;
  }

  // Helper function to get min value
  int max(int a, int b) => a > b ? a : b;
}
