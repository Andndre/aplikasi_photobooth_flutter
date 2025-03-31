import 'dart:async';
import 'dart:ffi' hide Size; // Add 'hide Size' to prevent ambiguity
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photobooth/models/event_model.dart';
import 'package:photobooth/providers/layout_provider.dart';
import 'package:photobooth/services/screen_capture_service.dart';
import 'package:provider/provider.dart';
import 'package:win32/win32.dart';
import '../providers/sesi_foto.dart';

class WindowCapturePreview extends StatefulWidget {
  final SesiFotoProvider provider;

  const WindowCapturePreview({super.key, required this.provider});

  @override
  WindowCapturePreviewState createState() => WindowCapturePreviewState();
}

class WindowCapturePreviewState extends State<WindowCapturePreview>
    with SingleTickerProviderStateMixin {
  Uint8List? _currentWindowCapture;
  bool _isCapturing = false;
  Timer? _captureTimer;
  int _captureWidth = 0;
  int _captureHeight = 0;
  int _originalWidth = 0;
  int _originalHeight = 0;
  int _framesReceived = 0;
  DateTime _lastFrameTime = DateTime.now();
  double _currentFps = 0;
  int _errorCount = 0;
  final _maxConsecutiveErrors = 5;
  bool _displayCaptureError = false;
  bool _isDirect = false; // Track if we're using direct bitmap data
  DateTime _lastCaptureTime = DateTime.now();
  final int _targetFrameTimeMs = 16; // ~60 FPS (1000ms / 60 = 16.67ms)
  int _skippedFrames = 0;
  int _renderedFrames = 0;
  bool _reducedPowerMode = false; // Disable reduced power mode by default
  bool _isGpuAccelerated = false;

  int _captureAttempts = 0;
  final int _maxCaptureAttempts = 5;
  bool _initialCaptureComplete = false;

  late AnimationController _refreshController;

  @override
  void initState() {
    super.initState();
    _setupAnimationController();
    // First attempt at preview capture
    _captureWindowForPreview(isInitialCapture: true);
  }

  void _setupAnimationController() {
    // Use a faster animation ticker to handle 60fps
    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16), // 60fps ticker
    )..repeat();

    // React to animation events, but throttle capture requests
    _refreshController.addListener(_onAnimationTick);
  }

  void _onAnimationTick() {
    // Skip some frames to reduce CPU load - with a more modest throttling
    _skippedFrames++;

    // In reduced power mode, only process every 2nd frame, but default is every frame
    final skipThreshold = _reducedPowerMode ? 2 : 1;

    if (_skippedFrames >= skipThreshold) {
      _skippedFrames = 0;

      final now = DateTime.now();
      final elapsed = now.difference(_lastCaptureTime).inMilliseconds;

      // Make sure we're not capturing too frequently
      if (!_isCapturing && elapsed >= _targetFrameTimeMs) {
        _captureWindowForPreview();
        _renderedFrames++;
      }
    }
  }

  @override
  void dispose() {
    _captureTimer?.cancel();
    _refreshController.dispose();
    super.dispose();
  }

  // Start capturing the window periodically for preview - only as fallback
  void _startPeriodicCapture() {
    _captureTimer?.cancel();

    // Set timer to match our 60 FPS target
    _captureTimer = Timer.periodic(Duration(milliseconds: _targetFrameTimeMs), (
      _,
    ) {
      // Only use timer-based capture if animation controller isn't working
      if (!_refreshController.isAnimating) {
        final now = DateTime.now();
        final elapsed = now.difference(_lastCaptureTime).inMilliseconds;

        if (!_isCapturing && elapsed >= _targetFrameTimeMs) {
          _captureWindowForPreview();
          _renderedFrames++;
        }
      }
    });
  }

  // Method to capture the window for preview display - optimized for performance
  Future<void> _captureWindowForPreview({bool isInitialCapture = false}) async {
    if (_isCapturing) return;

    final provider = widget.provider;
    if (provider.windowToCapture == null) {
      if (mounted) {
        setState(() {
          _displayCaptureError = false;
          _errorCount = 0;
          _captureAttempts = 0;
        });
      }
      return;
    }

    _isCapturing = true;
    _lastCaptureTime = DateTime.now();

    try {
      final captureResult = await provider.captureWindowWithSize();

      if (captureResult != null && mounted) {
        final capturedImageBytes = captureResult['bytes'] as Uint8List;
        final width = captureResult['width'] as int;
        final height = captureResult['height'] as int;
        final isDirect = captureResult['isDirect'] as bool;
        final originalWidth = captureResult['originalWidth'] as int? ?? width;
        final originalHeight =
            captureResult['originalHeight'] as int? ?? height;
        // Check if the capture is GPU accelerated
        final isGpuAccelerated =
            captureResult['isGpuAccelerated'] as bool? ?? false;

        // Reset error counters on successful capture
        _errorCount = 0;
        _captureAttempts = 0;
        _initialCaptureComplete = true;

        setState(() {
          _currentWindowCapture = capturedImageBytes;
          _captureWidth = width;
          _captureHeight = height;
          _originalWidth = originalWidth;
          _originalHeight = originalHeight;
          _isDirect = isDirect;
          _isGpuAccelerated =
              isGpuAccelerated; // Update GPU acceleration status
          _displayCaptureError = false;
        });

        // Start periodic capture after first successful capture
        if (isInitialCapture) {
          _startPeriodicCapture();
        }

        // Calculate and update FPS
        _framesReceived++;
        final now = DateTime.now();
        final elapsed = now.difference(_lastFrameTime).inMilliseconds;
        if (elapsed > 1000) {
          // Update FPS every second
          if (mounted) {
            setState(() {
              _currentFps = (_framesReceived * 1000) / elapsed;
              _framesReceived = 0;
              _lastFrameTime = now;
            });
          }
        }
      } else {
        // Increment attempt counter
        _captureAttempts++;

        if (_captureAttempts < _maxCaptureAttempts && isInitialCapture) {
          // Try again after a delay if we're still in initial capture phase
          Future.delayed(Duration(milliseconds: 500), () {
            if (mounted) {
              _isCapturing = false;
              _captureWindowForPreview(isInitialCapture: true);
            }
          });
          return;
        } else if (!_initialCaptureComplete && isInitialCapture) {
          // If all attempts failed during initial capture
          _errorCount = _maxConsecutiveErrors;
          setState(() {
            _displayCaptureError = true;
          });
        }
      }
    } catch (e) {
      _errorCount++;
      _captureAttempts++;

      if (_captureAttempts < _maxCaptureAttempts && isInitialCapture) {
        // Try again if initial capture
        Future.delayed(Duration(milliseconds: 500), () {
          if (mounted) {
            _isCapturing = false;
            _captureWindowForPreview(isInitialCapture: true);
          }
        });
        return;
      }

      // Only log serious errors to reduce log spam
      if (_errorCount % _maxConsecutiveErrors == 0) {
        print('Error capturing window: $e');
      }

      // Only show error state after several consecutive errors
      if (_errorCount >= _maxConsecutiveErrors && mounted) {
        setState(() {
          _displayCaptureError = true;
        });
      }
    } finally {
      _isCapturing = false;

      // Start timer for periodic capture if we're done with initial attempts
      if (isInitialCapture &&
          _captureAttempts >= _maxCaptureAttempts &&
          !_initialCaptureComplete) {
        _startPeriodicCapture();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get provider FPS for display
    final providerFps = widget.provider.currentFps;

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            // If we have a capture, display it - always show the image container to avoid flicker
            Container(
              color: Colors.black, // Stable background color
              child: Center(
                child:
                    _currentWindowCapture != null && !_displayCaptureError
                        ? _isDirect
                            ? RawImageDisplay(
                              imageBytes: _currentWindowCapture!,
                              width: _captureWidth,
                              height: _captureHeight,
                            )
                            : Image.memory(
                              _currentWindowCapture!,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                              errorBuilder: (context, error, stackTrace) {
                                print('Error displaying image: $error');
                                return const SizedBox(); // Empty widget on error
                              },
                            )
                        : const SizedBox(), // Empty widget instead of loading spinner
              ),
            ),

            // Show "no capture" or error message only when needed
            if (_currentWindowCapture == null || _displayCaptureError)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _displayCaptureError
                          ? Icons.error_outline
                          : Icons.photo_camera,
                      size: 48,
                      color:
                          _displayCaptureError
                              ? Colors.red.shade400
                              : Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _displayCaptureError
                          ? 'Error capturing window'
                          : widget.provider.windowToCapture == null
                          ? 'No window selected'
                          : _captureAttempts > 0
                          ? 'Trying to capture window... (Attempt ${_captureAttempts}/${_maxCaptureAttempts})'
                          : 'Preparing window capture...',
                      style: TextStyle(
                        fontSize: 18,
                        color:
                            _displayCaptureError ? Colors.red.shade400 : null,
                      ),
                    ),
                    if (_displayCaptureError)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton(
                          onPressed: () {
                            if (mounted) {
                              setState(() {
                                _displayCaptureError = false;
                                _errorCount = 0;
                                _captureAttempts = 0;
                              });
                              _captureWindowForPreview(isInitialCapture: true);
                            }
                          },
                          child: const Text('Retry Capture'),
                        ),
                      ),
                  ],
                ),
              ),

            // "Press Enter" text at the bottom
            if (_currentWindowCapture != null && !_displayCaptureError)
              const Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'Press Enter to Take Photo',
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      backgroundColor: Colors.black54,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            // FPS counter - small and unobtrusive in top left
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'UI: ${_currentFps.toStringAsFixed(1)} / Capture: ${providerFps.toStringAsFixed(1)} FPS',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _reducedPowerMode = !_reducedPowerMode;
                        });
                      },
                      child: Icon(
                        _reducedPowerMode ? Icons.battery_saver : Icons.speed,
                        size: 12,
                        color: _reducedPowerMode ? Colors.green : Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        widget.provider.toggleGpuAcceleration();
                      },
                      child: Icon(
                        _isGpuAccelerated
                            ? Icons.flash_on
                            : Icons.diamond_outlined,
                        size: 12,
                        color: _isGpuAccelerated ? Colors.cyan : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // GPU acceleration indicator
            if (_currentWindowCapture != null && !_displayCaptureError)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _isGpuAccelerated
                            ? Colors.cyan.withOpacity(0.7)
                            : Colors.grey.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isGpuAccelerated ? Icons.flash_on : Icons.flash_off,
                        size: 10,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _isGpuAccelerated ? 'GPU Mode' : 'CPU Mode',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Original resolution indicator
            if (_currentWindowCapture != null &&
                !_displayCaptureError &&
                _originalWidth > 0 &&
                _originalHeight > 0)
              Positioned(
                bottom: 60, // Position above the "Press Enter" text
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Original: ${_originalWidth}x$_originalHeight → Preview: ${_captureWidth}x$_captureHeight',
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// New widget to efficiently display raw image data without PNG conversion
class RawImageDisplay extends StatefulWidget {
  final Uint8List imageBytes;
  final int width;
  final int height;

  const RawImageDisplay({
    super.key,
    required this.imageBytes,
    required this.width,
    required this.height,
  });

  @override
  RawImageDisplayState createState() => RawImageDisplayState();
}

class RawImageDisplayState extends State<RawImageDisplay> {
  ui.Image? _image;
  ui.Image? _previousImage;
  bool _isConverting = false;
  String? _errorMessage;
  Size? _targetSize;
  late final Paint _imagePaint;

  @override
  void initState() {
    super.initState();
    // Configure image paint for better performance - use lowest quality
    _imagePaint =
        Paint()
          ..filterQuality = FilterQuality.none
          ..isAntiAlias = false;
    _convertToImage();
  }

  @override
  void didUpdateWidget(RawImageDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Optimize by checking if pixels have actually changed
    final bytesChanged = widget.imageBytes != oldWidget.imageBytes;
    final sizeChanged =
        widget.width != oldWidget.width || widget.height != oldWidget.height;

    if (sizeChanged || bytesChanged) {
      _convertToImage();
    }
  }

  Future<void> _convertToImage() async {
    if (_isConverting) return;

    _isConverting = true;

    try {
      // Use the highest performance method available for image conversion
      final completer = Completer<ui.Image>();

      ui.decodeImageFromPixels(
        widget.imageBytes,
        widget.width,
        widget.height,
        ui.PixelFormat.rgba8888,
        (ui.Image result) {
          completer.complete(result);
        },
        // Don't scale during decode, as we'll do that during painting
        // for better performance
        rowBytes: widget.width * 4,
      );

      final image = await completer.future;

      if (mounted) {
        setState(() {
          _previousImage = _image;
          _image = image;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Image conversion error';
        });
      }
      // Add this error log as it's important for debugging
      print('Error converting image: $e');
    } finally {
      _isConverting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use RepaintBoundary to optimize rendering performance
    return RepaintBoundary(
      child:
          _image != null
              ? CustomPaint(
                painter: RawImagePainter(
                  image: _image!,
                  thisPaint: _imagePaint,
                ),
                size: Size(widget.width.toDouble(), widget.height.toDouble()),
              )
              : _previousImage != null
              ? CustomPaint(
                painter: RawImagePainter(
                  image: _previousImage!,
                  thisPaint: _imagePaint,
                ),
                size: Size(widget.width.toDouble(), widget.height.toDouble()),
              )
              : Container(color: Colors.black),
    );
  }
}

// Custom painter to efficiently render the ui.Image
class RawImagePainter extends CustomPainter {
  final ui.Image image;
  final Paint thisPaint;

  RawImagePainter({required this.image, required this.thisPaint});

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate optimal scaling
    final double scaleX = size.width / image.width;
    final double scaleY = size.height / image.height;
    final double scale = math.min(scaleX, scaleY);

    // Calculate centered position
    final double left = (size.width - (image.width * scale)) / 2;
    final double top = (size.height - (image.height * scale)) / 2;

    final Rect rect = Rect.fromLTWH(
      left,
      top,
      image.width * scale,
      image.height * scale,
    );

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      rect,
      thisPaint,
    );
  }

  @override
  bool shouldRepaint(RawImagePainter oldDelegate) {
    // Only repaint if the image reference has changed
    return oldDelegate.image != image;
  }
}

// Widget for the window selection dropdown
class WindowSelectionDropdown extends StatefulWidget {
  final SesiFotoProvider provider;

  const WindowSelectionDropdown({super.key, required this.provider});

  @override
  WindowSelectionDropdownState createState() => WindowSelectionDropdownState();
}

class WindowSelectionDropdownState extends State<WindowSelectionDropdown> {
  List<WindowInfo> _availableWindows = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableWindows();
  }

  // Gunakan metode dari service untuk mendapat daftar window
  void _loadAvailableWindows() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Gunakan fungsi dari service
      final windows = await ScreenCaptureService.getWindowsList();

      // Add a slight delay to ensure UI updates properly
      await Future.delayed(const Duration(milliseconds: 100));

      if (mounted) {
        setState(() {
          _availableWindows = windows;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading windows: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Ensure we have at least one window available
          if (_availableWindows.isEmpty) {
            _availableWindows = [
              WindowInfo(hwnd: 0, title: 'No windows found'),
            ];
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentWindow = widget.provider.windowToCapture;
    final captureMethod = widget.provider.captureMethod;

    return Badge(
      isLabelVisible: currentWindow == null,
      backgroundColor: Theme.of(context).colorScheme.error,
      smallSize: 8,
      child: PopupMenuButton(
        icon: const Icon(Icons.settings),
        tooltip:
            currentWindow == null
                ? 'Select a window to capture'
                : 'Capture Settings',
        position: PopupMenuPosition.under,
        // Refresh window list when menu is opened
        onOpened: _loadAvailableWindows,
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
          minWidth: 300,
        ),
        itemBuilder:
            (context) => [
              PopupMenuItem(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 300),
                  child: IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Window Selection',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              child:
                                  _isLoading
                                      ? const Center(
                                        child: SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                      : DropdownButton<int>(
                                        value: currentWindow?.hwnd,
                                        isExpanded: true,
                                        onChanged: (int? newValue) {
                                          if (newValue != null) {
                                            if (newValue == 0) {
                                              widget.provider
                                                  .setWindowToCapture(null);
                                            } else {
                                              final selectedWindow =
                                                  _availableWindows.firstWhere(
                                                    (window) =>
                                                        window.hwnd == newValue,
                                                    orElse:
                                                        () =>
                                                            _availableWindows
                                                                .first,
                                                  );

                                              if (selectedWindow.hwnd != 0) {
                                                widget.provider
                                                    .setWindowToCapture(
                                                      selectedWindow,
                                                    );
                                              } else {
                                                widget.provider
                                                    .setWindowToCapture(null);
                                              }
                                            }
                                          }
                                          Navigator.pop(context);
                                        },
                                        items:
                                            _availableWindows
                                                .map<DropdownMenuItem<int>>((
                                                  window,
                                                ) {
                                                  return DropdownMenuItem<int>(
                                                    value: window.hwnd,
                                                    child: Text(
                                                      window.title,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  );
                                                })
                                                .toList(),
                                      ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 20),
                              onPressed: () {
                                _loadAvailableWindows();
                              },
                            ),
                          ],
                        ),

                        const Divider(),
                        const Text(
                          'Performance Settings',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Extreme Power Saving:"),
                            Switch(
                              value: widget.provider.extremeOptimizationMode,
                              onChanged: (value) {
                                widget.provider.toggleExtremeOptimizationMode();
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Use GPU Acceleration:"),
                            Switch(
                              value: widget.provider.useGpuAcceleration,
                              onChanged: (value) {
                                widget.provider.toggleGpuAcceleration();
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Capture Method: (Auto-selected based on window type)',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getCaptureMethodName(captureMethod),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
      ),
    );
  }

  // Helper method to get the name of the capture method
  String _getCaptureMethodName(CaptureMethod method) {
    switch (method) {
      case CaptureMethod.standard:
        return 'Standard (BitBlt/PrintWindow)';
      case CaptureMethod.printWindow:
        return 'PrintWindow (Better Compatibility)';
      case CaptureMethod.fullscreen:
        return 'Fullscreen/Browser Mode';
    }
  }

  // Show a help dialog explaining the different capture methods
  void _showCaptureMethodHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Capture Methods'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCaptureMethodInfo(
                'Standard',
                'Standard window capture. Works for most basic applications.',
              ),
              const SizedBox(height: 8),
              _buildCaptureMethodInfo(
                'PrintWindow',
                'Better compatibility with more applications but may use more CPU.',
              ),
              const SizedBox(height: 8),
              _buildCaptureMethodInfo(
                'Fullscreen/Browser Mode',
                'Best for browsers, OBS, and fullscreen applications.',
              ),
              const SizedBox(height: 16),
              const Text(
                'The best capture method is automatically selected based on the window type.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Helper method to build each capture method info item
  Widget _buildCaptureMethodInfo(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(description, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class SesiFoto extends StatefulWidget {
  final EventModel event;

  const SesiFoto({required this.event, super.key});

  @override
  SesiFotoState createState() => SesiFotoState();
}

class SesiFotoState extends State<SesiFoto> {
  bool _isFullscreen = false;

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });

    final hwnd = FindWindow(nullptr, TEXT('photobooth'));
    if (hwnd != 0) {
      if (_isFullscreen) {
        // Get screen dimensions
        final width = GetSystemMetrics(SM_CXSCREEN);
        final height = GetSystemMetrics(SM_CYSCREEN);
        // Set borderless style but keep the title bar
        SetWindowLongPtr(hwnd, GWL_STYLE, WS_OVERLAPPED | WS_VISIBLE);
        // Set window position to cover entire screen
        SetWindowPos(hwnd, 0, 0, 0, width, height, SWP_FRAMECHANGED);
      } else {
        // Restore window decorations
        SetWindowLongPtr(hwnd, GWL_STYLE, WS_OVERLAPPEDWINDOW | WS_VISIBLE);
        // Restore window size and position
        ShowWindow(hwnd, SW_RESTORE);
      }
    }
  }

  Widget _buildLoadingOverlay() {
    return Provider.of<SesiFotoProvider>(context).isLoading
        ? Container(
          color: Colors.black54,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  Provider.of<SesiFotoProvider>(context).loadingMessage,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        )
        : const SizedBox.shrink();
  }

  @override
  void dispose() {
    // Restore system UI when disposing
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sesiFotoProvider = Provider.of<SesiFotoProvider>(context);
    final layoutsProvider = Provider.of<LayoutsProvider>(
      context,
      listen: false,
    );

    return FutureBuilder(
      future: layoutsProvider.loadLayouts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else {
          final layout = widget.event.getLayout(context);

          // Add retake status indicator
          final isRetakeMode = sesiFotoProvider.retakePhotoIndex != null;
          final retakeIndex = sesiFotoProvider.retakePhotoIndex;

          return Scaffold(
            appBar: AppBar(
              title: Text('Sesi Foto: ${widget.event.name}'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.camera_alt),
                  onPressed:
                      () => sesiFotoProvider.takePhoto(
                        widget.event.saveFolder,
                        widget.event.uploadFolder,
                        widget.event.name,
                        layout,
                        context,
                      ),
                  tooltip: 'Take Photo (Enter)',
                ),
                WindowSelectionDropdown(provider: sesiFotoProvider),
                IconButton(
                  icon: Icon(
                    _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  ),
                  onPressed: _toggleFullscreen,
                  tooltip: 'Toggle Fullscreen (F11)',
                ),
              ],
            ),
            body: Stack(
              children: [
                CallbackShortcuts(
                  bindings: <ShortcutActivator, VoidCallback>{
                    // Change to Enter key instead of F1
                    const SingleActivator(LogicalKeyboardKey.enter): () {
                      print('Taking picture');
                      sesiFotoProvider.takePhoto(
                        widget.event.saveFolder,
                        widget.event.uploadFolder,
                        widget.event.name,
                        layout,
                        context,
                      );
                    },
                    const SingleActivator(LogicalKeyboardKey.f11):
                        _toggleFullscreen,
                  },
                  child: Focus(
                    autofocus: true,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isLandscape =
                            constraints.maxWidth > constraints.maxHeight;
                        return isLandscape
                            ? Row(
                              children: [
                                // Large screen capture preview (left section)
                                Expanded(
                                  flex:
                                      4, // Changed from 2 to 4 for bigger preview
                                  child: WindowCapturePreview(
                                    provider: sesiFotoProvider,
                                  ),
                                ),

                                // Taken photos grid (right section) - made narrower
                                SizedBox(
                                  width: 250, // Changed from 300 to 250
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerLow,
                                      border: const Border(
                                        left: BorderSide(
                                          color: Colors.grey,
                                          width: 0.5,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Text(
                                            'Captured Photos (${sesiFotoProvider.takenPhotos.length})',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child:
                                              sesiFotoProvider
                                                      .takenPhotos
                                                      .isEmpty
                                                  ? const Center(
                                                    child: Text(
                                                      'No photos captured yet.\nPress Enter to take a photo.',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  )
                                                  : GridView.builder(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          16,
                                                        ),
                                                    gridDelegate:
                                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                                          crossAxisCount: 2,
                                                          crossAxisSpacing: 8.0,
                                                          mainAxisSpacing: 8.0,
                                                        ),
                                                    itemCount:
                                                        sesiFotoProvider
                                                            .takenPhotos
                                                            .length,
                                                    itemBuilder: (
                                                      context,
                                                      index,
                                                    ) {
                                                      final photo =
                                                          sesiFotoProvider
                                                              .takenPhotos[index];
                                                      return Card(
                                                        clipBehavior:
                                                            Clip.antiAlias,
                                                        elevation: 3.0,
                                                        child: Stack(
                                                          fit: StackFit.expand,
                                                          children: [
                                                            Image.file(
                                                              photo,
                                                              fit: BoxFit.cover,
                                                            ),
                                                            Positioned(
                                                              top: 4,
                                                              right: 4,
                                                              child: Container(
                                                                padding:
                                                                    const EdgeInsets.all(
                                                                      4,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  color: Colors
                                                                      .black
                                                                      .withOpacity(
                                                                        0.6,
                                                                      ),
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        12,
                                                                      ),
                                                                ),
                                                                child: Text(
                                                                  '${index + 1}',
                                                                  style: const TextStyle(
                                                                    color:
                                                                        Colors
                                                                            .white,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                            : Column(
                              children: [
                                // Large screen capture preview (top section)
                                Expanded(
                                  flex:
                                      4, // Changed from 2 to 4 for bigger preview
                                  child: WindowCapturePreview(
                                    provider: sesiFotoProvider,
                                  ),
                                ),

                                // Bottom section - made smaller
                                Expanded(
                                  flex: 1, // Added flex: 1 to make it smaller
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerLow,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(16),
                                        topRight: Radius.circular(16),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 12.0,
                                            bottom: 8.0,
                                          ),
                                          child: Text(
                                            'Captured Photos (${sesiFotoProvider.takenPhotos.length})',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child:
                                              sesiFotoProvider
                                                      .takenPhotos
                                                      .isEmpty
                                                  ? const Center(
                                                    child: Text(
                                                      'No photos captured yet.\nPress Enter to take a photo.',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  )
                                                  : GridView.builder(
                                                    gridDelegate:
                                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                                          crossAxisCount: 4,
                                                          crossAxisSpacing: 8.0,
                                                          mainAxisSpacing: 8.0,
                                                        ),
                                                    itemCount:
                                                        sesiFotoProvider
                                                            .takenPhotos
                                                            .length,
                                                    itemBuilder: (
                                                      context,
                                                      index,
                                                    ) {
                                                      final photo =
                                                          sesiFotoProvider
                                                              .takenPhotos[index];
                                                      return Card(
                                                        clipBehavior:
                                                            Clip.antiAlias,
                                                        elevation: 3.0,
                                                        child: Stack(
                                                          fit: StackFit.expand,
                                                          children: [
                                                            Image.file(
                                                              photo,
                                                              fit: BoxFit.cover,
                                                            ),
                                                            Positioned(
                                                              top: 4,
                                                              right: 4,
                                                              child: Container(
                                                                padding:
                                                                    const EdgeInsets.all(
                                                                      4,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  color: Colors
                                                                      .black
                                                                      .withOpacity(
                                                                        0.6,
                                                                      ),
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        12,
                                                                      ),
                                                                ),
                                                                child: Text(
                                                                  '${index + 1}',
                                                                  style: const TextStyle(
                                                                    color:
                                                                        Colors
                                                                            .white,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                      },
                    ),
                  ),
                ),

                // Loading overlay
                _buildLoadingOverlay(),

                // Move the retake banner here to ensure it's on top of everything else
                if (isRetakeMode)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.orange.withOpacity(0.9),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12.0,
                        horizontal: 16.0,
                      ),
                      width: double.infinity,
                      child: Text(
                        'Retaking Photo ${retakeIndex! + 1} - Press Enter to capture',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }
      },
    );
  }
}
