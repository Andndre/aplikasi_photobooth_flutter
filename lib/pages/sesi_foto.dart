import 'dart:ffi' hide Size; // Add 'hide Size' to prevent ambiguity
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photobooth/models/event_model.dart';
import 'package:photobooth/pages/photo_preset_page.dart'; // Add this import
import 'package:photobooth/providers/layout_provider.dart';
import 'package:photobooth/providers/sesi_foto.dart';
import 'package:photobooth/components/dialogs/composite_images_dialog.dart';
import 'package:photobooth/components/sesi_foto/window_capture_preview.dart';
import 'package:photobooth/components/sesi_foto/window_selection_dropdown.dart';
import 'package:provider/provider.dart';
import 'package:win32/win32.dart';

class SesiFoto extends StatefulWidget {
  final EventModel event;

  const SesiFoto({required this.event, super.key});

  @override
  SesiFotoState createState() => SesiFotoState();
}

class SesiFotoState extends State<SesiFoto> {
  bool _isFullscreen = false;
  bool _isLoadingLayouts = false;
  bool _layoutsLoaded = false;
  bool _previousLoadingState = false;

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
    final provider = Provider.of<SesiFotoProvider>(context);

    if (!provider.isLoading) return const SizedBox.shrink();

    return AnimatedOpacity(
      opacity: provider.isLoading ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          color: Colors.black54,
          alignment: Alignment.center,
          child: Card(
            elevation: 8,
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  provider.progressValue != null
                      ? Column(
                        children: [
                          SizedBox(
                            width: 300,
                            child: LinearProgressIndicator(
                              value: provider.progressValue,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "${(provider.progressValue! * 100).toInt()}%",
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      )
                      : const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(strokeWidth: 4),
                      ),
                  const SizedBox(height: 16),
                  Text(
                    provider.loadingMessage,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (provider.subMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        provider.subMessage,
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Restore system UI when disposing
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Load layouts immediately in initState
    _loadLayouts();
  }

  // Separate method to load layouts once
  Future<void> _loadLayouts() async {
    if (_layoutsLoaded) return;

    setState(() {
      _isLoadingLayouts = true;
    });

    // Get the provider
    final layoutsProvider = Provider.of<LayoutsProvider>(
      context,
      listen: false,
    );

    try {
      // Show loading in the provider
      final sesiFotoProvider = Provider.of<SesiFotoProvider>(
        context,
        listen: false,
      );
      sesiFotoProvider.setLoading(
        true,
        'Loading layouts...',
        'Please wait',
        null,
      );

      // Wait for layouts to load
      await layoutsProvider.loadLayouts();

      // Clear loading if it was our loading message
      if (sesiFotoProvider.loadingMessage == 'Loading layouts...') {
        sesiFotoProvider.setLoading(false);
      }
    } catch (e) {
      print('Error loading layouts: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLayouts = false;
          _layoutsLoaded = true;
        });
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

    // Get layout without triggering FutureBuilder
    final layout = _layoutsLoaded ? widget.event.getLayout(context) : null;

    return Scaffold(
      appBar: _buildAppBar(context, sesiFotoProvider, layout),
      body: Stack(
        children: [
          // Only build main content if layout is available
          if (layout != null)
            _buildKeyboardShortcuts(context, sesiFotoProvider, layout),

          // Retake banner only if layout available and in retake mode
          if (sesiFotoProvider.retakePhotoIndex != null && layout != null)
            _buildRetakeBanner(sesiFotoProvider.retakePhotoIndex),

          // Loading overlay - handles all loading states
          _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    SesiFotoProvider sesiFotoProvider,
    dynamic layout,
  ) {
    // Add retake status indicator
    final isRetakeMode = sesiFotoProvider.retakePhotoIndex != null;
    final retakeIndex = sesiFotoProvider.retakePhotoIndex;

    return Scaffold(
      appBar: _buildAppBar(context, sesiFotoProvider, layout),
      body: Stack(
        children: [
          // Only build main content if layout is available
          if (layout != null)
            _buildKeyboardShortcuts(context, sesiFotoProvider, layout),

          // Retake banner only if layout available and in retake mode
          if (isRetakeMode && layout != null) _buildRetakeBanner(retakeIndex),

          // Loading overlay - now handles all loading states
          _buildLoadingOverlay(),
        ],
      ),
    );
  }

  AppBar _buildAppBar(
    BuildContext context,
    SesiFotoProvider sesiFotoProvider,
    dynamic layout,
  ) {
    return AppBar(
      title: Text('Sesi Foto: ${widget.event.name}'),
      actions: [
        // Add photo presets button
        IconButton(
          icon: const Icon(Icons.auto_fix_high),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PhotoPresetPage()),
            );
          },
          tooltip: 'Photo Presets',
        ),
        // Add new gallery button
        IconButton(
          icon: const Icon(Icons.photo_library),
          onPressed: () {
            showDialog(
              context: context,
              builder:
                  (context) => CompositeImagesDialog(
                    eventName: widget.event.name,
                    uploadFolder: widget.event.uploadFolder,
                  ),
            );
          },
          tooltip: 'View Gallery',
        ),
        // Only enable camera button when layout is loaded
        IconButton(
          icon: const Icon(Icons.camera_alt),
          onPressed:
              layout != null
                  ? () => sesiFotoProvider.takePhoto(
                    widget.event.saveFolder,
                    widget.event.uploadFolder,
                    widget.event.name,
                    layout,
                    context,
                  )
                  : null,
          tooltip: 'Take Photo (Enter)',
        ),
        WindowSelectionDropdown(provider: sesiFotoProvider),
        IconButton(
          icon: Icon(_isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
          onPressed: _toggleFullscreen,
          tooltip: 'Toggle Fullscreen (F11)',
        ),
      ],
    );
  }

  Widget _buildKeyboardShortcuts(
    BuildContext context,
    SesiFotoProvider sesiFotoProvider,
    dynamic layout,
  ) {
    return CallbackShortcuts(
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
        const SingleActivator(LogicalKeyboardKey.f11): _toggleFullscreen,
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > constraints.maxHeight;
            return isLandscape
                ? _buildLandscapeLayout(context, sesiFotoProvider)
                : _buildPortraitLayout(context, sesiFotoProvider);
          },
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout(
    BuildContext context,
    SesiFotoProvider sesiFotoProvider,
  ) {
    return Row(
      children: [
        // Large screen capture preview (left section)
        Expanded(
          flex: 4, // Changed from 2 to 4 for bigger preview
          child: WindowCapturePreview(provider: sesiFotoProvider),
        ),

        // Taken photos grid (right section) - made narrower
        SizedBox(
          width: 250, // Changed from 300 to 250
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              border: const Border(
                left: BorderSide(color: Colors.grey, width: 0.5),
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
                Expanded(child: _buildPhotoGrid(sesiFotoProvider, 2)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitLayout(
    BuildContext context,
    SesiFotoProvider sesiFotoProvider,
  ) {
    return Column(
      children: [
        // Large screen capture preview (top section)
        Expanded(
          flex: 4, // Changed from 2 to 4 for bigger preview
          child: WindowCapturePreview(provider: sesiFotoProvider),
        ),

        // Bottom section - made smaller
        Expanded(
          flex: 1, // Added flex: 1 to make it smaller
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                  child: Text(
                    'Captured Photos (${sesiFotoProvider.takenPhotos.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Expanded(child: _buildPhotoGrid(sesiFotoProvider, 4)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoGrid(
    SesiFotoProvider sesiFotoProvider,
    int crossAxisCount,
  ) {
    return sesiFotoProvider.takenPhotos.isEmpty
        ? const Center(
          child: Text(
            'No photos captured yet.\nPress Enter to take a photo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        )
        : GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8.0,
            mainAxisSpacing: 8.0,
          ),
          itemCount: sesiFotoProvider.takenPhotos.length,
          itemBuilder: (context, index) {
            final photo = sesiFotoProvider.takenPhotos[index];
            return Card(
              clipBehavior: Clip.antiAlias,
              elevation: 3.0,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(photo, fit: BoxFit.cover),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
  }

  Widget _buildRetakeBanner(int? retakeIndex) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.orange.withOpacity(0.9),
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
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
    );
  }
}
