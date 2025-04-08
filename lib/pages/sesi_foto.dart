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
import 'dart:io';

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

  void _clearImageCache() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    if (mounted) {
      setState(() {});
    }
  }

  void _handleProviderChanges() {
    final provider = Provider.of<SesiFotoProvider>(context, listen: false);

    if (provider.retakePhotoIndex == null) {
      _clearImageCache();
    }
  }

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
    final provider = Provider.of<SesiFotoProvider>(context, listen: false);
    provider.removeListener(_handleProviderChanges);

    if (_isFullscreen) {
      final hwnd = FindWindow(nullptr, TEXT('photobooth'));
      if (hwnd != 0) {
        SetWindowLongPtr(hwnd, GWL_STYLE, WS_OVERLAPPEDWINDOW | WS_VISIBLE);
        ShowWindow(hwnd, SW_RESTORE);
        _isFullscreen = false;
      }
    }

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadLayouts();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setActivePresetFromEvent();

      final provider = Provider.of<SesiFotoProvider>(context, listen: false);
      provider.addListener(_handleProviderChanges);
    });
  }

  void _setActivePresetFromEvent() {
    if (!mounted) return;

    final presetProvider = Provider.of<PresetProvider>(context, listen: false);
    final eventPresetId = widget.event.presetId;

    if (eventPresetId.isNotEmpty) {
      print('Setting active preset to match event preset ID: $eventPresetId');

      final presetExists = presetProvider.getPresetById(eventPresetId) != null;

      if (presetExists) {
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

  Future<void> _loadLayouts() async {
    if (_layoutsLoaded) return;

    final layoutsProvider = Provider.of<LayoutsProvider>(
      context,
      listen: false,
    );

    try {
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

      await layoutsProvider.loadLayouts();

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

    final layout = _layoutsLoaded ? widget.event.getLayout(context) : null;

    return Scaffold(
      body: Stack(
        children: [
          if (layout != null)
            _buildKeyboardShortcuts(context, sesiFotoProvider, layout),

          if (sesiFotoProvider.retakePhotoIndex != null && layout != null)
            _buildRetakeBanner(sesiFotoProvider.retakePhotoIndex),

          _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    SesiFotoProvider sesiFotoProvider,
    dynamic layout,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, size: 18),
          onPressed: () {
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
        Expanded(
          flex: 4,
          child: WindowCapturePreview(provider: sesiFotoProvider),
        ),
        SizedBox(
          width: 245,
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
                if (sesiFotoProvider.compositeJobs.isNotEmpty ||
                    sesiFotoProvider.isLoading)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: _buildSidebarLoadingIndicator(sesiFotoProvider),
                  ),
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
        Expanded(
          flex: 4,
          child: WindowCapturePreview(provider: sesiFotoProvider),
        ),
        Expanded(
          flex: 1,
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
                if (sesiFotoProvider.compositeJobs.isNotEmpty ||
                    sesiFotoProvider.isLoading)
                  _buildSidebarLoadingIndicator(sesiFotoProvider),
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
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    return sesiFotoProvider.takenPhotos.isEmpty
        ? const Center(
          child: Text(
            'No photos captured yet.\nPress Enter to take a photo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        )
        : GridView.builder(
          key: ValueKey('photo-grid-$timestamp'),
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8.0,
            mainAxisSpacing: 8.0,
          ),
          itemCount: sesiFotoProvider.takenPhotos.length,
          itemBuilder: (context, index) {
            final photoPath = sesiFotoProvider.takenPhotos[index].path;
            final photo = File(photoPath);

            return Card(
              clipBehavior: Clip.antiAlias,
              elevation: 3.0,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FutureBuilder<FileStat>(
                    future: photo.stat(),
                    builder: (context, snapshot) {
                      final statInfo = snapshot.data?.toString() ?? '';
                      return Image.file(
                        photo,
                        key: ValueKey('$photoPath-$timestamp-$statInfo'),
                        fit: BoxFit.cover,
                        cacheWidth: null,
                        cacheHeight: null,
                        errorBuilder: (context, error, stackTrace) {
                          print('Error loading sidebar image: $error');
                          return Center(
                            child: Icon(Icons.broken_image, color: Colors.red),
                          );
                        },
                      );
                    },
                  ),
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
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap:
                            () => sesiFotoProvider.setRetakePhotoIndex(index),
                        child: Container(
                          padding: const EdgeInsets.all(6.0),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.refresh,
                            color: Colors.white,
                            size: 16,
                          ),
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
