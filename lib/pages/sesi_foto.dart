import 'dart:io';
import 'dart:async';
import 'dart:ffi';

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

  @override
  void initState() {
    super.initState();
    // Capture once immediately to get initial size
    _captureWindowForPreview().then((_) {
      // Start periodic capture after we have the initial size
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
    // Use a longer interval to reduce flickering (250ms = 4fps)
    _captureTimer?.cancel();
    _captureTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!_isCapturing) {
        _captureWindowForPreview();
      }
    });
  }

  // Method to capture the window for preview display
  Future<void> _captureWindowForPreview() async {
    if (_isCapturing) return; // Prevent multiple simultaneous captures

    final provider = widget.provider;
    if (provider.windowToCapture == null) return;

    _isCapturing = true;

    try {
      final captureResult = await provider.captureWindowWithSize();
      if (captureResult != null && mounted) {
        final capturedImageBytes = captureResult['bytes'] as Uint8List;
        final width = captureResult['width'] as int;
        final height = captureResult['height'] as int;

        if (!mounted) return;
        setState(() {
          _currentWindowCapture = capturedImageBytes;
          _captureWidth = width;
          _captureHeight = height;
        });
      }
    } catch (e) {
      print('Error capturing window: $e');
    } finally {
      _isCapturing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            // Capture display
            _currentWindowCapture != null
                ? Center(
                  child: Image.memory(
                    _currentWindowCapture!,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                )
                : const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'No window capture available',
                        style: TextStyle(fontSize: 18),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Press Enter to Take Photo',
                        style: TextStyle(fontSize: 24),
                      ),
                    ],
                  ),
                ),

            // Window selection dropdown positioned at the top right
            Positioned(
              top: 8,
              right: 8,
              child: WindowSelectionDropdown(provider: widget.provider),
            ),
          ],
        ),
      ),
    );
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
    setState(() {
      _isLoading = true;
    });

    try {
      final windows = _getWindowsList();
      setState(() {
        _availableWindows = windows;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading windows: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Function to get the list of windows
  List<WindowInfo> _getWindowsList() {
    final windows = <WindowInfo>[];

    // Define the callback function
    final enumWindowsProc = Pointer.fromFunction<EnumWindowsProc>(
      _enumWindowsCallback,
      0, // Returning 0 means stop enumeration, 1 means continue
    );

    // Store the windows list in a global variable to access from the callback
    _tempWindowsList = windows;

    // Call the Win32 EnumWindows function
    EnumWindows(enumWindowsProc, 0);

    return windows;
  }

  // Temporary storage for the windows list during enumeration
  static List<WindowInfo>? _tempWindowsList;

  // Callback function for EnumWindows
  static int _enumWindowsCallback(int hwnd, int lParam) {
    if (IsWindowVisible(hwnd) != 0) {
      final buffer = calloc<Uint16>(1024).cast<Utf16>();
      GetWindowText(hwnd, buffer, 1024);
      final title = buffer.toDartString();
      calloc.free(buffer);

      if (title.isNotEmpty) {
        _tempWindowsList?.add(WindowInfo(hwnd: hwnd, title: title));
      }
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
                    // Find the window with matching hwnd
                    final selectedWindow = _availableWindows.firstWhere(
                      (window) => window.hwnd == newValue,
                      orElse: () => _availableWindows.first,
                    );
                    widget.provider.setWindowToCapture(selectedWindow);
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
                                          return Container(
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: Colors.grey.shade300,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(7),
                                              child: Image.file(
                                                sesiFotoProvider
                                                    .takenPhotos[index],
                                                fit: BoxFit.cover,
                                              ),
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
