import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photobooth/components/sesi_foto/raw_image_display.dart';
import 'package:photobooth/providers/sesi_foto.dart';

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
  bool _reducedPowerMode = false; // Disable reduced power mode by default

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
    // Get countdown state
    final isCountingDown = widget.provider.isCountingDown;
    final countdownValue = widget.provider.countdownValue;

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
                          ? 'Trying to capture window... (Attempt $_captureAttempts/$_maxCaptureAttempts)'
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
              Positioned(
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

            // Countdown overlay - show on top of everything else
            if (isCountingDown)
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(60),
                  ),
                  child: Center(
                    child: Text(
                      countdownValue.toString(),
                      style: const TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
