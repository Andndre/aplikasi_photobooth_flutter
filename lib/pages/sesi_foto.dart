import 'dart:ffi' hide Size; // Add 'hide Size' to prevent ambiguity
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photobooth/models/event_model.dart';
import 'package:photobooth/pages/photo_preset_page.dart'; // Add this import
import 'package:photobooth/providers/layout_provider.dart';
import 'package:photobooth/providers/preset_provider.dart';
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
  bool _layoutsLoaded = false;

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

  // New function to build the loading indicators in the sidebar
  Widget _buildSidebarLoadingIndicator(SesiFotoProvider provider) {
    if (provider.compositeJobs.isEmpty && !provider.isLoading) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (provider.isLoading) _buildGeneralLoadingIndicator(provider),

        // Build composite job indicators
        ...provider.compositeJobs.map(
          (job) => _buildCompositeJobIndicator(job),
        ),
      ],
    );
  }

  // For general loading tasks (not composite related)
  Widget _buildGeneralLoadingIndicator(SesiFotoProvider provider) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.loadingMessage,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (provider.subMessage.isNotEmpty)
                    Text(
                      provider.subMessage,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // For composite job indicators
  Widget _buildCompositeJobIndicator(CompositeJob job) {
    Color statusColor =
        job.hasError
            ? Colors.red
            : job.isComplete
            ? Colors.green
            : Colors.blue;

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  job.hasError
                      ? Icons.error
                      : job.isComplete
                      ? Icons.check_circle
                      : Icons.hourglass_top,
                  color: statusColor,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Processing '${job.eventName}'",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (job.progressValue != null)
              LinearProgressIndicator(
                value: job.progressValue,
                minHeight: 4,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            const SizedBox(height: 8),
            Text(
              job.message,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              job.subMessage,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return const SizedBox.shrink(); // No longer used
  }

  @override
  void dispose() {
    // Exit fullscreen mode if active when leaving the page
    if (_isFullscreen) {
      final hwnd = FindWindow(nullptr, TEXT('photobooth'));
      if (hwnd != 0) {
        // Restore window decorations
        SetWindowLongPtr(hwnd, GWL_STYLE, WS_OVERLAPPEDWINDOW | WS_VISIBLE);
        // Restore window size and position
        ShowWindow(hwnd, SW_RESTORE);
        _isFullscreen = false;
      }
    }

    // Restore system UI when disposing
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Load layouts immediately in initState
    _loadLayouts();

    // Set the active preset to match the event's preset
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setActivePresetFromEvent();
    });
  }

  // New method to set the active preset based on the event's presetId
  void _setActivePresetFromEvent() {
    if (!mounted) return;

    final presetProvider = Provider.of<PresetProvider>(context, listen: false);
    final eventPresetId = widget.event.presetId;

    if (eventPresetId.isNotEmpty) {
      print('Setting active preset to match event preset ID: $eventPresetId');

      // Check if the preset exists before setting it as active
      final presetExists = presetProvider.getPresetById(eventPresetId) != null;

      if (presetExists) {
        // Set this preset as the active preset and also update the current event
        presetProvider.setActivePreset(
          eventPresetId,
          context: context,
          currentEvent: widget.event,
        );
        print('Successfully set active preset to: $eventPresetId');
      } else {
        print('Event preset ID $eventPresetId not found in saved presets');
      }
    }
  }

  // Separate method to load layouts once
  Future<void> _loadLayouts() async {
    if (_layoutsLoaded) return;

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
      // AppBar removed here
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

  // This method is now removed as we don't use AppBar anymore
  // AppBar _buildAppBar(...) {...}

  // Helper method to build the action buttons that were in the AppBar
  Widget _buildActionButtons(
    SesiFotoProvider sesiFotoProvider,
    dynamic layout,
  ) {
    return Row(
      // Change to space-between to put back button on the left and other actions on right
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Back button on the left
        IconButton(
          icon: const Icon(Icons.arrow_back, size: 18),
          onPressed: () {
            // Exit fullscreen mode if active before navigating back
            if (_isFullscreen) {
              final hwnd = FindWindow(nullptr, TEXT('photobooth'));
              if (hwnd != 0) {
                SetWindowLongPtr(
                  hwnd,
                  GWL_STYLE,
                  WS_OVERLAPPEDWINDOW | WS_VISIBLE,
                );
                ShowWindow(hwnd, SW_RESTORE);
              }
            }
            Navigator.of(context).pop();
          },
          tooltip: 'Back',
        ),

        // Other buttons grouped on the right
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.auto_fix_high, size: 18),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PhotoPresetPage(),
                  ),
                );
              },
              tooltip: 'Photo Presets',
            ),
            IconButton(
              icon: const Icon(Icons.photo_library, size: 18),
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
            IconButton(
              icon: const Icon(Icons.camera_alt, size: 18),
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
              icon: Icon(
                _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                size: 18,
              ),
              onPressed: _toggleFullscreen,
              tooltip: 'Toggle Fullscreen (F11)',
            ),
          ],
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
                ? _buildLandscapeLayout(context, sesiFotoProvider, layout)
                : _buildPortraitLayout(context, sesiFotoProvider, layout);
          },
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout(
    BuildContext context,
    SesiFotoProvider sesiFotoProvider,
    dynamic layout,
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
          width: 245, // Changed from 300 to 250
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
                // Add the action buttons that were in the AppBar
                _buildActionButtons(sesiFotoProvider, layout),
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
                // Add loading indicators at the top of the photo grid
                if (sesiFotoProvider.compositeJobs.isNotEmpty ||
                    sesiFotoProvider.isLoading)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: _buildSidebarLoadingIndicator(sesiFotoProvider),
                  ),
                // Existing photo grid
                Expanded(child: _buildPhotoGrid(sesiFotoProvider, 1)),
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
    dynamic layout,
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
                // Add the title and event name
                Padding(
                  padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
                  child: Text(
                    'Sesi Foto: ${widget.event.name}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Add the action buttons that were in the AppBar
                _buildActionButtons(sesiFotoProvider, layout),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                  child: Text(
                    'Captured Photos (${sesiFotoProvider.takenPhotos.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                // Add loading indicators at the top of the photo grid
                if (sesiFotoProvider.compositeJobs.isNotEmpty ||
                    sesiFotoProvider.isLoading)
                  _buildSidebarLoadingIndicator(sesiFotoProvider),
                // Existing photo grid
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
