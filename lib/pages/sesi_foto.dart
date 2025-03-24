import 'dart:io';
import 'dart:async';
import 'dart:ffi' hide Size; // Add 'hide Size' to prevent ambiguity
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:aplikasi_photobooth_flutter/pages/start_event.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:win32/win32.dart';
import '../models/event.dart';
import '../providers/sesi_foto.dart';
import '../providers/layouts.dart';

// Create a separate stateful widget for the window capture preview
class WindowCapturePreview extends StatefulWidget {
  final SesiFotoProvider provider;

  const WindowCapturePreview({super.key, required this.provider});

  @override
  WindowCapturePreviewState createState() => WindowCapturePreviewState();
}

class WindowCapturePreviewState extends State<WindowCapturePreview> {
  Uint8List? _currentWindowCapture;
  bool _isCapturing = false;
  Timer? _captureTimer;
  int _captureWidth = 0;
  int _captureHeight = 0;
  int _framesReceived = 0;
  DateTime _lastFrameTime = DateTime.now();
  double _currentFps = 0;
  int _errorCount = 0;
  final _maxConsecutiveErrors = 5;
  bool _displayCaptureError = false;
  bool _isDirect = false; // Track if we're using direct bitmap data

  @override
  void initState() {
    super.initState();
    _captureWindowForPreview().then((_) {
      _startPeriodicCapture();
    });
  }

  @override
  void dispose() {
    _captureTimer?.cancel();
    super.dispose();
  }

  // Start capturing the window periodically for preview
  void _startPeriodicCapture() {
    _captureTimer?.cancel();

    // Set timer to ~33ms for approximately 30fps
    _captureTimer = Timer.periodic(const Duration(milliseconds: 15), (_) {
      if (!_isCapturing) {
        _captureWindowForPreview();
      }
    });
  }

  // Method to capture the window for preview display
  Future<void> _captureWindowForPreview() async {
    if (_isCapturing) return; // Prevent multiple simultaneous captures

    final provider = widget.provider;
    if (provider.windowToCapture == null) {
      setState(() {
        _displayCaptureError = false;
        _errorCount = 0;
      });
      return;
    }

    _isCapturing = true;

    try {
      final captureResult = await provider.captureWindowWithSize();
      if (captureResult != null && mounted) {
        final capturedImageBytes = captureResult['bytes'] as Uint8List;
        final width = captureResult['width'] as int;
        final height = captureResult['height'] as int;
        final isDirect = captureResult['isDirect'] as bool;

        setState(() {
          _currentWindowCapture = capturedImageBytes;
          _captureWidth = width;
          _captureHeight = height;
          _isDirect = isDirect;
          _displayCaptureError = false;
          _errorCount = 0;
        });

        // Calculate and update FPS
        _framesReceived++;
        final now = DateTime.now();
        final elapsed = now.difference(_lastFrameTime).inMilliseconds;
        if (elapsed > 1000) {
          // Update FPS every second
          setState(() {
            _currentFps = (_framesReceived * 1000) / elapsed;
            _framesReceived = 0;
            _lastFrameTime = now;
          });
        }
      }
    } catch (e) {
      _errorCount++;

      // Only show error state after several consecutive errors
      if (_errorCount >= _maxConsecutiveErrors && mounted) {
        setState(() {
          _displayCaptureError = true;
        });
      }

      print('Error capturing window: $e');
    } finally {
      _isCapturing = false;
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
            // If we have a capture, display it
            if (_currentWindowCapture != null && !_displayCaptureError)
              Center(
                child:
                    _isDirect
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
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 48,
                                    color: Colors.red.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Error displaying capture',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Try Again'),
                                    onPressed: () {
                                      setState(() {
                                        _displayCaptureError = false;
                                        _errorCount = 0;
                                        _currentWindowCapture = null;
                                      });
                                      _captureWindowForPreview();
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
              ),

            // Show "no capture" or error message
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
                          : 'Preparing window capture...',
                      style: TextStyle(
                        fontSize: 18,
                        color:
                            _displayCaptureError ? Colors.red.shade400 : null,
                      ),
                    ),
                    // ...existing code...
                  ],
                ),
              ),

            // Window selection dropdown positioned at the top right
            Positioned(
              top: 8,
              right: 8,
              child: WindowSelectionDropdown(provider: widget.provider),
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
                  ],
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
    Key? key,
    required this.imageBytes,
    required this.width,
    required this.height,
  }) : super(key: key);

  @override
  RawImageDisplayState createState() => RawImageDisplayState();
}

class RawImageDisplayState extends State<RawImageDisplay> {
  ui.Image? _image;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _convertToImage();
  }

  @override
  void didUpdateWidget(RawImageDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only recreate the image if size changed or image data changed
    if (oldWidget.width != widget.width ||
        oldWidget.height != widget.height ||
        oldWidget.imageBytes != widget.imageBytes) {
      _convertToImage();
    }
  }

  Future<void> _convertToImage() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // More efficient way to create an image from raw RGBA data
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        widget.imageBytes,
        widget.width,
        widget.height,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );

      final image = await completer.future;

      if (mounted) {
        setState(() {
          _image = image;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error converting raw image: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _image == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return CustomPaint(
      painter: RawImagePainter(image: _image!),
      size: Size(widget.width.toDouble(), widget.height.toDouble()),
    );
  }
}

// Custom painter to efficiently render the ui.Image
class RawImagePainter extends CustomPainter {
  final ui.Image image;

  RawImagePainter({required this.image});

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate scale to fit the image within the available space
    final double scaleX = size.width / image.width;
    final double scaleY = size.height / image.height;
    final double scale = scaleX < scaleY ? scaleX : scaleY;

    // Calculate centered position
    final double left = (size.width - (image.width * scale)) / 2;
    final double top = (size.height - (image.height * scale)) / 2;

    // Create a rect for the image
    final Rect rect = Rect.fromLTWH(
      left,
      top,
      image.width * scale,
      image.height * scale,
    );

    // Draw the image
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      rect,
      Paint(),
    );
  }

  @override
  bool shouldRepaint(RawImagePainter oldDelegate) {
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

  // Function to load all available windows
  void _loadAvailableWindows() async {
    if (_isLoading) return; // Prevent multiple simultaneous calls

    setState(() {
      _isLoading = true;
    });

    try {
      final windows = _getWindowsList();

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

  // Function to get the list of windows
  List<WindowInfo> _getWindowsList() {
    final windows = <WindowInfo>[];

    try {
      // Define the callback function
      final enumWindowsProc = Pointer.fromFunction<EnumWindowsProc>(
        _enumWindowsCallback,
        0, // Returning 0 means stop enumeration, 1 means continue
      );

      // Store the windows list in a global variable to access from the callback
      _tempWindowsList = windows;

      // Call the Win32 EnumWindows function
      final result = EnumWindows(enumWindowsProc, 0);
      if (result == 0) {
        print('EnumWindows failed');
      }

      // Add a special entry for "None" so user can deselect
      windows.insert(0, WindowInfo(hwnd: 0, title: 'Select a window...'));

      return windows;
    } catch (e) {
      print('Error in _getWindowsList: $e');
      return [WindowInfo(hwnd: 0, title: 'Error loading windows')];
    }
  }

  // Temporary storage for the windows list during enumeration
  static List<WindowInfo>? _tempWindowsList;

  // Callback function for EnumWindows
  static int _enumWindowsCallback(int hwnd, int lParam) {
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
            if (!title.toLowerCase().contains('aplikasi_photobooth_flutter')) {
              _tempWindowsList?.add(WindowInfo(hwnd: hwnd, title: title));
            }
          }
        }

        calloc.free(buffer);
      }
    } catch (e) {
      print('Error in _enumWindowsCallback: $e');
    }

    return TRUE; // Continue enumeration
  }

  @override
  Widget build(BuildContext context) {
    // Get current selected window
    final currentWindow = widget.provider.windowToCapture;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Capture Window:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          _isLoading
              ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
              : DropdownButton<int>(
                // Change the type parameter to int
                value: currentWindow?.hwnd, // Use hwnd as the value
                onChanged: (int? newValue) {
                  if (newValue != null) {
                    if (newValue == 0) {
                      // User selected "None"
                      widget.provider.setWindowToCapture(null);
                    } else {
                      // Find the window with matching hwnd
                      final selectedWindow = _availableWindows.firstWhere(
                        (window) => window.hwnd == newValue,
                        orElse: () => _availableWindows.first,
                      );
                      widget.provider.setWindowToCapture(selectedWindow);
                    }
                  }
                },
                items:
                    _availableWindows.map<DropdownMenuItem<int>>((
                      WindowInfo window,
                    ) {
                      // Each DropdownMenuItem uses hwnd (int) as its value
                      return DropdownMenuItem<int>(
                        value: window.hwnd,
                        child: SizedBox(
                          width:
                              150, // Constrain width to avoid excessive dropdown size
                          child: Text(
                            window.title,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      );
                    }).toList(),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                underline: Container(height: 0),
                dropdownColor: Colors.grey[800],
                style: const TextStyle(color: Colors.white),
                // Handle empty state
                hint: const Text(
                  "Select a window",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
            onPressed: _loadAvailableWindows,
            tooltip: 'Refresh window list',
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

class SesiFoto extends StatefulWidget {
  final Event event;

  const SesiFoto({required this.event, super.key});

  @override
  SesiFotoState createState() => SesiFotoState();
}

class SesiFotoState extends State<SesiFoto> {
  final int _photoCount = 1; // Start from 1

  // Method to capture the selected window and save it
  Future<void> _captureSelectedWindow() async {
    final provider = Provider.of<SesiFotoProvider>(context, listen: false);

    if (provider.windowToCapture == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No window selected for capture')),
      );
      return;
    }

    try {
      final capturedImageBytes = await provider.captureWindow();
      if (capturedImageBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/window_capture.png');
        await tempFile.writeAsBytes(capturedImageBytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error capturing image: $e')));
      }
    }
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

          return Scaffold(
            appBar: AppBar(title: Text('Sesi Foto: ${widget.event.name}')),
            body: CallbackShortcuts(
              bindings: <ShortcutActivator, VoidCallback>{
                const SingleActivator(LogicalKeyboardKey.enter):
                    _captureSelectedWindow,
                // Add refresh shortcut
                const SingleActivator(LogicalKeyboardKey.keyR): () {
                  // This shortcut is kept for convenience but no longer needs a visible button
                },
              },
              child: Focus(
                autofocus: true,
                child: Column(
                  children: [
                    // Large screen capture preview (top section)
                    Expanded(
                      flex: 2,
                      child: WindowCapturePreview(provider: sesiFotoProvider),
                    ),

                    // Taken photos grid (bottom section)
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.surfaceContainerLow,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                  sesiFotoProvider.takenPhotos.isEmpty
                                      ? const Center(
                                        child: Text(
                                          'No photos captured yet.\nPress Enter to take a photo.',
                                          textAlign: TextAlign.center,
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
                                            sesiFotoProvider.takenPhotos.length,
                                        itemBuilder: (context, index) {
                                          final photo =
                                              sesiFotoProvider
                                                  .takenPhotos[index];
                                          return Card(
                                            clipBehavior: Clip.antiAlias,
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
                                                        const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black
                                                          .withOpacity(0.6),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      '${index + 1}',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
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
                ),
              ),
            ),
          );
        }
      },
    );
  }
}
