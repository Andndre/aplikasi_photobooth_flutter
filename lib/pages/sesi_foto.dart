import 'dart:async';
import 'dart:ffi' hide Size; // Add 'hide Size' to prevent ambiguity
import 'dart:ui' as ui;

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photobooth/models/event_model.dart';
import 'package:photobooth/pages/start_event.dart';
import 'package:photobooth/providers/layout_provider.dart';
import 'package:provider/provider.dart';
import 'package:win32/win32.dart';
import '../providers/sesi_foto.dart';

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

        if (capturedImageBytes.isNotEmpty) {
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
        } else {
          print('Warning: Empty image data received');
          _errorCount++;
        }
      }
    } catch (e) {
      _errorCount++;
      print('Error capturing window: $e');

      // Only show error state after several consecutive errors
      if (_errorCount >= _maxConsecutiveErrors && mounted) {
        setState(() {
          _displayCaptureError = true;
        });
      }
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
                          : 'Preparing window capture...',
                      style: TextStyle(
                        fontSize: 18,
                        color:
                            _displayCaptureError ? Colors.red.shade400 : null,
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
  ui.Image? _previousImage; // Keep the previous image to prevent flickering
  bool _isConverting = false;
  String? _errorMessage;

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
    // Skip if we're already converting to prevent race conditions
    if (_isConverting) return;

    _isConverting = true;
    String? conversionError;

    try {
      // Validate the image data first
      if (widget.imageBytes.length < widget.width * widget.height * 4) {
        throw Exception(
          'Invalid image data: bytes length (${widget.imageBytes.length}) '
          'is less than expected (${widget.width * widget.height * 4})',
        );
      }

      // Debug information
      // print('Converting raw image: ${widget.width}x${widget.height}, bytes: ${widget.imageBytes.length}');

      // Use a try-catch block specifically for the decodeImageFromPixels call
      try {
        // Create the image without using setState during conversion
        final completer = Completer<ui.Image>();
        ui.decodeImageFromPixels(
          widget.imageBytes,
          widget.width,
          widget.height,
          ui.PixelFormat.rgba8888,
          completer.complete,
          rowBytes: widget.width * 4,
        );

        final image = await completer.future;

        // Only update UI if the widget is still mounted
        if (mounted) {
          setState(() {
            // Save the previous image before replacing it
            _previousImage = _image;
            _image = image;
            _errorMessage = null;
          });
        }
      } catch (decodeError) {
        print('Error in decodeImageFromPixels: $decodeError');

        // Try alternative approach with ImageCodec
        try {
          final codec = await ui.instantiateImageCodec(widget.imageBytes);
          final frame = await codec.getNextFrame();

          if (mounted) {
            setState(() {
              _previousImage = _image;
              _image = frame.image;
              _errorMessage = null;
            });
          }
        } catch (codecError) {
          print('Error with codec approach: $codecError');
          conversionError = codecError.toString();
        }
      }
    } catch (e) {
      print('Error converting raw image: $e');
      conversionError = e.toString();
    } finally {
      // Update error state if needed, but only if we're still mounted
      if (mounted && conversionError != null) {
        setState(() {
          _errorMessage = conversionError;
        });
      }

      _isConverting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // If we have a current image, display it
    if (_image != null) {
      return CustomPaint(
        painter: RawImagePainter(image: _image!),
        size: Size(widget.width.toDouble(), widget.height.toDouble()),
      );
    }

    // If we have a previous image, show it to prevent flickering while loading new one
    if (_previousImage != null) {
      return CustomPaint(
        painter: RawImagePainter(image: _previousImage!),
        size: Size(widget.width.toDouble(), widget.height.toDouble()),
      );
    }

    // Only show an empty container or error if we have no images at all
    if (_errorMessage != null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Text(
            'Image Error',
            style: TextStyle(color: Colors.red.shade400),
          ),
        ),
      );
    }

    // Blank space instead of a spinner
    return Container(color: Colors.black);
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
                              child: DropdownButton<int>(
                                value: currentWindow?.hwnd,
                                isExpanded: true,
                                onChanged: (int? newValue) {
                                  if (newValue != null) {
                                    if (newValue == 0) {
                                      widget.provider.setWindowToCapture(null);
                                    } else {
                                      final selectedWindow = _availableWindows
                                          .firstWhere(
                                            (window) => window.hwnd == newValue,
                                            orElse:
                                                () => _availableWindows.first,
                                          );
                                      widget.provider.setWindowToCapture(
                                        selectedWindow,
                                      );
                                    }
                                  }
                                  Navigator.pop(context);
                                },
                                items:
                                    _availableWindows
                                        .map<DropdownMenuItem<int>>((window) {
                                          return DropdownMenuItem<int>(
                                            value: window.hwnd,
                                            child: Text(
                                              window.title,
                                              overflow: TextOverflow.ellipsis,
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
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                        const Divider(),
                        const Text(
                          'Capture Method',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              child: DropdownButton<CaptureMethod>(
                                value: captureMethod,
                                isExpanded: true,
                                onChanged: (CaptureMethod? newMethod) {
                                  if (newMethod != null) {
                                    widget.provider.setCaptureMethod(newMethod);
                                  }
                                  Navigator.pop(context);
                                },
                                items:
                                    CaptureMethod.values.map<
                                      DropdownMenuItem<CaptureMethod>
                                    >((method) {
                                      return DropdownMenuItem<CaptureMethod>(
                                        value: method,
                                        child: Text(
                                          _getCaptureMethodName(method),
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      );
                                    }).toList(),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.help_outline, size: 20),
                              onPressed: () {
                                Navigator.pop(context);
                                _showCaptureMethodHelp(context);
                              },
                            ),
                          ],
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
      case CaptureMethod.bitBlt:
        return 'BitBlt (Default)';
      case CaptureMethod.windowsGraphicsCapture:
        return 'Windows Graphics Capture';
      case CaptureMethod.printWindow:
        return 'PrintWindow';
      case CaptureMethod.dxgi:
        return 'DXGI Desktop Duplication';
      case CaptureMethod.browserSpecific:
        return 'Browser Specific';
      case CaptureMethod.fullscreenApp:
        return 'Fullscreen App';
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
                'BitBlt (Default)',
                'Standard window capture. Works with most applications.',
              ),
              const SizedBox(height: 8),
              _buildCaptureMethodInfo(
                'Windows Graphics Capture',
                'Better for UWP apps and games. Requires Windows 10.',
              ),
              const SizedBox(height: 8),
              _buildCaptureMethodInfo(
                'PrintWindow',
                'Alternative method that can capture some windows that BitBlt cannot.',
              ),
              const SizedBox(height: 8),
              _buildCaptureMethodInfo(
                'DXGI Desktop Duplication',
                'Best for games and hardware-accelerated content. Higher performance.',
              ),
              const SizedBox(height: 8),
              _buildCaptureMethodInfo(
                'Browser Specific',
                'Optimized for Chrome, Edge, Firefox and other browsers with hardware acceleration.',
              ),
              const SizedBox(height: 8),
              _buildCaptureMethodInfo(
                'Fullscreen App',
                'For OBS Projector, games, and other fullscreen applications.',
              ),
              const SizedBox(height: 16),
              const Text(
                'For Chrome/Edge browsers, use Browser Specific.\nFor OBS Projector, use Fullscreen App.',
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
            body: CallbackShortcuts(
              bindings: <ShortcutActivator, VoidCallback>{
                const SingleActivator(LogicalKeyboardKey.enter): () {
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
                              flex: 4, // Changed from 2 to 4 for bigger preview
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                                padding: const EdgeInsets.all(
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
                                                itemBuilder: (context, index) {
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
                              flex: 4, // Changed from 2 to 4 for bigger preview
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
                                                    sesiFotoProvider
                                                        .takenPhotos
                                                        .length,
                                                itemBuilder: (context, index) {
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
          );
        }
      },
    );
  }
}
