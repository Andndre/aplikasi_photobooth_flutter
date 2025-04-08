import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:photobooth/components/dialogs/composite_images_dialog.dart';
import 'package:photobooth/components/dialogs/captured_photos_dialog.dart';
import 'package:photobooth/models/layout_model.dart';
import 'package:photobooth/models/preset_model.dart';
import 'package:photobooth/models/renderables/renderer.dart';
import 'package:photobooth/providers/preset_provider.dart';
import 'package:photobooth/providers/event_provider.dart'; // Add this import
import 'package:photobooth/services/image_processor.dart';
import 'package:provider/provider.dart';
import 'package:win32/win32.dart';
import 'package:path/path.dart' as path;
// Import service
import 'package:photobooth/services/screen_capture_service.dart';

enum SortOrder { newest, oldest }

class SesiFotoProvider with ChangeNotifier {
  final List<File> _takenPhotos = [];
  List<File> _compositeImages = [];
  bool _isLoading = false;
  String _loadingMessage = '';
  String _subMessage = '';
  double? _progressValue;
  SortOrder _sortOrder = SortOrder.newest;

  // Buat instance screen capture service
  final ScreenCaptureService _screenCaptureService = ScreenCaptureService();

  // Add retake photo index tracker
  int? _retakePhotoIndex;
  int? get retakePhotoIndex => _retakePhotoIndex;

  // Add countdown state
  int _countdownValue = 0;
  bool _isCountingDown = false;

  int get countdownValue => _countdownValue;
  bool get isCountingDown => _isCountingDown;

  // Delegate ke screen capture service
  CaptureMethod get captureMethod => _screenCaptureService.captureMethod;
  double get currentFps => _screenCaptureService.currentFps;
  bool get extremeOptimizationMode =>
      _screenCaptureService.extremeOptimizationMode;
  WindowInfo? get windowToCapture => _screenCaptureService.windowToCapture;

  List<File> get takenPhotos => _takenPhotos;
  List<File> get compositeImages => _compositeImages;
  SortOrder get sortOrder => _sortOrder;
  bool get isLoading => _isLoading;
  String get loadingMessage => _loadingMessage;
  String get subMessage => _subMessage;
  double? get progressValue => _progressValue;

  void _setLoading(
    bool isLoading, [
    String message = '',
    String subMessage = '',
    double? progress,
  ]) {
    _isLoading = isLoading;
    _loadingMessage = message;
    _subMessage = subMessage;
    _progressValue = progress;
    notifyListeners();
  }

  // Make this public to allow showing loading state from any component
  void setLoading(
    bool isLoading, [
    String message = '',
    String subMessage = '',
    double? progress,
  ]) {
    _isLoading = isLoading;
    _loadingMessage = message;
    _subMessage = subMessage;
    _progressValue = progress;
    notifyListeners();
  }

  // Arahkan method-method ke service
  void toggleExtremeOptimizationMode() {
    _screenCaptureService.toggleExtremeOptimizationMode();
    notifyListeners();
  }

  void setCaptureMethod(CaptureMethod method) {
    _screenCaptureService.setCaptureMethod(method);
    notifyListeners();
  }

  void setWindowToCapture(WindowInfo? window) {
    _screenCaptureService.setWindowToCapture(window);
    notifyListeners();
  }

  // Set retake photo index
  void setRetakePhotoIndex(int? index) {
    _retakePhotoIndex = index;
    notifyListeners();
  }

  // Delegasikan ke service
  Future<Map<String, dynamic>?> captureWindowWithSize() {
    return _screenCaptureService.captureWindowWithSize();
  }

  Future<Uint8List?> captureWindow() {
    return _screenCaptureService.captureWindow();
  }

  Future<void> takePhoto(
    String saveFolder,
    String uploadFolder,
    String eventName,
    LayoutModel layout,
    BuildContext context,
  ) async {
    // If already counting down, don't start another countdown
    if (_isCountingDown) return;

    final hwnd = FindWindowEx(0, 0, nullptr, TEXT('WhatsApp'));
    if (hwnd == 0) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Error'),
              content: const Text('Imaging Edge Remote tidak ditemukan!'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
      return;
    }

    // Start countdown from 3
    setState(() {
      _isCountingDown = true;
      _countdownValue = 3;
    });

    // Countdown sequence
    for (int i = 3; i > 0; i--) {
      setState(() {
        _countdownValue = i;
      });
      await Future.delayed(const Duration(seconds: 1));
    }

    // Reset countdown state after countdown
    setState(() {
      _isCountingDown = false;
      _countdownValue = 0;
    });

    // Store a reference to the photobooth window
    final photoboothHwnd = FindWindow(nullptr, TEXT('photobooth'));
    if (photoboothHwnd == 0) {
      print('Warning: Could not find photobooth window');
    }

    SetForegroundWindow(hwnd);
    await Future.delayed(const Duration(milliseconds: 300));

    // Simulate key press for '1'
    final input = calloc<INPUT>();
    input.ref.type = INPUT_KEYBOARD;
    input.ref.ki.wVk = VK_1;
    SendInput(1, input, sizeOf<INPUT>());
    await Future.delayed(const Duration(seconds: 1, milliseconds: 500));
    input.ref.ki.dwFlags = KEYEVENTF_KEYUP;
    SendInput(1, input, sizeOf<INPUT>());
    calloc.free(input);

    print("Foto diambil.");

    // Wait longer to ensure Remote has completed its operation
    await Future.delayed(const Duration(seconds: 4));

    // Explicitly force focus back to photobooth with multiple attempts
    if (photoboothHwnd != 0) {
      print("Attempting to return focus to photobooth...");

      // Try multiple techniques to ensure focus returns
      SetForegroundWindow(photoboothHwnd);

      // Try showing window normally first
      ShowWindow(photoboothHwnd, SW_SHOW);

      // Force foreground again after a small delay
      await Future.delayed(const Duration(milliseconds: 100));
      SetForegroundWindow(photoboothHwnd);

      // If needed, try activating the window too
      await Future.delayed(const Duration(milliseconds: 100));
      SetActiveWindow(photoboothHwnd);
    }

    // Get the latest photo from the save folder
    final directory = Directory(saveFolder);
    if (await directory.exists()) {
      final files = directory.listSync().whereType<File>().toList();
      files.sort(
        (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
      );

      if (files.isNotEmpty) {
        final newPhoto = files.first;

        // Handle retake case
        if (_retakePhotoIndex != null) {
          // We're retaking a photo - replace the existing one
          final index = _retakePhotoIndex!;
          final oldPhoto = _takenPhotos[index];
          final oldPath = oldPhoto.path;

          // Copy the new photo to replace the old one
          newPhoto.copySync(oldPath);
          _takenPhotos[index] = File(oldPath);

          // Reset retake index
          _retakePhotoIndex = null;

          // Show captured photos dialog again - ensure context is valid
          if (context.mounted) {
            await _showCapturedPhotosDialog(
              saveFolder,
              uploadFolder,
              eventName,
              layout,
              context,
            );
          }
        } else {
          // Normal case - add the new photo
          _takenPhotos.add(files.first);

          // Find camera elements in the layout to determine when we have all photos
          final cameraElements =
              layout.elements.where((e) => e.type == 'camera').toList();

          // If all photos are taken, show captured photos dialog - ensure context is valid
          if (_takenPhotos.length == cameraElements.length && context.mounted) {
            await _showCapturedPhotosDialog(
              saveFolder,
              uploadFolder,
              eventName,
              layout,
              context,
            );
          }
        }

        notifyListeners();
      }
    }

    print("Foto disimpan. Jumlah foto: ${_takenPhotos.length}");
  }

  Future<void> _showCapturedPhotosDialog(
    String saveFolder,
    String uploadFolder,
    String eventName,
    LayoutModel layout,
    BuildContext context,
  ) async {
    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => CapturedPhotosDialog(
            photos: _takenPhotos,
            onRetake: (index) {
              // Set the retake index
              setRetakePhotoIndex(index);
              // Close the dialog using the dialog's context
              Navigator.of(dialogContext).pop();
            },
            onConfirm: () async {
              // Close the dialog using the dialog's context
              Navigator.of(dialogContext).pop();
              await generateComposite(uploadFolder, eventName, layout, context);
            },
            onCancel: () {
              // Close the dialog without generating composite
              Navigator.of(dialogContext).pop();
              // Clear all captured photos when canceling
              _clearTakenPhotos();
            },
          ),
    );
  }

  Future<void> generateComposite(
    String uploadFolder,
    String eventName,
    LayoutModel layout,
    BuildContext context,
  ) async {
    // Add assertions for debugging
    assert(uploadFolder.isNotEmpty, 'Upload folder is empty');
    assert(eventName.isNotEmpty, 'Event name is empty');

    _setLoading(true, 'Starting composite generation...', 'Preparing...', 0.0);
    // Small delay to ensure loading UI is visible
    await Future.delayed(const Duration(milliseconds: 200));

    final existingFiles =
        Directory(uploadFolder).listSync().whereType<File>().toList();
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
        }
      } catch (e) {
        continue;
      }
    }

    // Create output paths
    final compositeImagePath = path.join(
      uploadFolder,
      'Luminara_${eventName}_${maxCompositeIndex + 2}_composite.jpg',
    );

    final gifPath = path.join(
      uploadFolder,
      'Luminara_${eventName}_${maxCompositeIndex + 2}_gif.gif',
    );

    // Remove folder creation for individual photos - we'll save directly to the upload folder

    _setLoading(true, 'Processing photos with preset...', 'Preparing...', 0.05);
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      // Find the event by name
      final eventProvider = Provider.of<EventsProvider>(context, listen: false);

      final event = eventProvider.events.firstWhereOrNull(
        (e) => e.name == eventName,
      );

      // Debug prints for event and preset
      print(
        '📸 Processing composite for event: ${event?.name ?? "NO EVENT FOUND"}',
      );

      if (event != null) {
        print('📋 Event preset ID: "${event.presetId}"');
      } else {
        print('⚠️ Event not found by name: $eventName');
      }

      PresetModel? eventPreset;
      final presetProvider = Provider.of<PresetProvider>(
        context,
        listen: false,
      );

      print(
        'Available presets: ${presetProvider.savedPresets.map((p) => "${p.id} (${p.name})").join(", ")}',
      );

      // DEBUG line to help diagnose preset issues
      print(
        '❗ DEBUG: Event presetId = "${event?.presetId}", Default preset ID = "default"',
      );

      if (event != null && event.presetId.isNotEmpty) {
        // FIXED: First ensure we're using the correct preset ID, not attempting to match by name
        if (event.presetId == "default" &&
            presetProvider.savedPresets.length > 1) {
          print(
            '⚠️ Event is using default preset ID, trying active preset instead',
          );

          // Use active preset if available
          final activePreset = presetProvider.activePreset;
          if (activePreset != null && activePreset.id != "default") {
            print(
              '✅ Using active preset instead: ${activePreset.name} (${activePreset.id})',
            );

            // Also update the event's preset ID to match the active preset for future use
            event.updatePresetId(activePreset.id);
            eventPreset = activePreset;

            // Save the updated event
            try {
              final eventsProvider = Provider.of<EventsProvider>(
                context,
                listen: false,
              );
              await eventsProvider.saveEvents(); // Add await here
              print(
                '✅ Updated event "${event.name}" preset ID to: ${activePreset.id}',
              );
            } catch (e) {
              print('⚠️ Could not save updated event: $e');
            }
          }
        }

        // If we didn't find a preset yet, use direct lookup
        if (eventPreset == null) {
          // Direct lookup from PresetProvider by ID for reliability
          print('Looking up preset directly by ID: "${event.presetId}"');
          eventPreset = presetProvider.getPresetById(event.presetId);
        }

        if (eventPreset != null) {
          print('✅ Successfully found preset by ID: ${eventPreset.name}');
        } else {
          print(
            '⚠️ Direct preset lookup failed, trying through event.getPreset()',
          );

          // If direct lookup fails, try through the event's getPreset method
          eventPreset = event.getPreset(context);
          print('📋 Result from event.getPreset(): ${eventPreset?.name}');
        }
      } else {
        // No event or no preset ID, use active preset directly from provider
        print('⚠️ No event/presetId, falling back to active preset');
        eventPreset = presetProvider.activePreset;
        print('📋 Active preset: ${eventPreset?.name ?? "None"}');
      }

      // Final fallback to default preset - should rarely get here
      if (eventPreset == null) {
        print('❌ All preset lookups failed, creating default preset');
        eventPreset = PresetModel.defaultPreset();
      }

      // Print preset parameters to verify we got the right one
      print('✅ Using preset: ${eventPreset.name} (ID: ${eventPreset.id})');
      print('   - Brightness: ${eventPreset.brightness}');
      print('   - Contrast: ${eventPreset.contrast}');
      print('   - Saturation: ${eventPreset.saturation}');

      // PROCESS THE PHOTOS WITH PRESET - OPTIMIZED VERSION
      _setLoading(
        true,
        'Applying preset "${eventPreset.name}"',
        'Processing photos in parallel...',
        0.1,
      );
      await Future.delayed(const Duration(milliseconds: 200));

      print(
        "About to process ${_takenPhotos.length} photos with preset: ${eventPreset.name}",
      );

      // Process photos in parallel with progress tracking
      List<File> processedPhotos =
          await ImageProcessor.batchProcessImagesWithProgress(
            _takenPhotos,
            eventPreset,
            (progress, message) {
              _setLoading(
                true,
                'Applying preset "${eventPreset?.name}"',
                message,
                progress * 0.6,
              );
            },
          );

      // Ensure we have a small pause after processing to let user see the progress
      await Future.delayed(const Duration(milliseconds: 300));

      // Modified code: Save individual processed photos directly to upload folder
      _setLoading(
        true,
        'Saving individual processed photos',
        'Copying files...',
        0.5,
      );

      List<File> savedIndividualPhotos = [];
      for (int i = 0; i < processedPhotos.length; i++) {
        File processedPhoto = processedPhotos[i];
        String fileName = path.basename(processedPhoto.path);
        String destPath = path.join(
          uploadFolder,
          'Luminara_${eventName}_${maxCompositeIndex + 2}_photo_${i + 1}${path.extension(fileName)}',
        );

        // Copy the processed photo to the destination
        File savedPhoto = await processedPhoto.copy(destPath);
        savedIndividualPhotos.add(savedPhoto);

        // Update progress
        _setLoading(
          true,
          'Saving individual processed photos',
          'Saved ${i + 1} of ${processedPhotos.length}',
          0.5 + ((i + 1) / processedPhotos.length * 0.1),
        );
      }

      print(
        'Successfully saved ${savedIndividualPhotos.length} individual processed photos to $uploadFolder',
      );

      // First start the GIF generation process which takes longer
      _setLoading(
        true,
        'Creating composite images',
        'Starting GIF creation...',
        0.6,
      );

      // Start gif creation but don't await it yet
      final gifFuture = ImageProcessor.createOptimizedGif(
        images: processedPhotos.map((file) => file.path).toList(),
        outputPath: gifPath,
        progressCallback: (progress) {
          _setLoading(
            true,
            'Creating GIF animation',
            'Optimizing frames: ${(progress * 100).toInt()}%',
            0.6 + (progress * 0.2),
          );
        },
      );

      // Now create the composite image
      _setLoading(true, 'Creating composite image', 'Rendering layout...', 0.8);
      await Future.delayed(const Duration(milliseconds: 300));

      // Export the composite image using processed photos
      final exportedFile = await Renderer.exportLayoutWithImages(
        layout: layout,
        exportPath: compositeImagePath,
        filePaths: processedPhotos.map((file) => file.path).toList(),
        resolutionMultiplier: 1,
      );

      if (exportedFile != null) {
        print('Composite image created: ${exportedFile.path}');
        _setLoading(
          true,
          'Composite image created successfully',
          'Waiting for GIF creation to complete...',
          0.9,
        );
        await Future.delayed(const Duration(milliseconds: 300));
      } else {
        print('Failed to create composite image');
        _setLoading(
          true,
          'Error creating composite image',
          'Continuing with GIF creation...',
          0.9,
        );
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Wait for GIF to complete
      _setLoading(true, 'Finalizing GIF animation', 'Please wait...', 0.95);
      final gifFile = await gifFuture;

      if (gifFile != null) {
        print('GIF animation created: ${gifFile.path}');
        _setLoading(
          true,
          'Processing complete',
          'All images have been created successfully.',
          1.0,
        );
      } else {
        print('Failed to create GIF animation');
        _setLoading(
          true,
          'Processing complete',
          'GIF creation failed, but composite image was created.',
          1.0,
        );
      }

      // Show completion status for a moment before closing
      await Future.delayed(const Duration(seconds: 1));
      _setLoading(false);

      // Show the composite images dialog - ensure context is valid
      if (context.mounted) {
        await showDialog(
          context: context,
          builder:
              (dialogContext) => CompositeImagesDialog(
                eventName: eventName,
                uploadFolder: uploadFolder,
              ),
        );
      }

      // Clear the taken photos list after successfully generating composite images
      _clearTakenPhotos();
    } catch (e) {
      print('Error creating composite image or GIF: $e');
      _setLoading(true, 'Error processing images', e.toString(), null);
      await Future.delayed(const Duration(seconds: 3));
      _setLoading(false);
    }
  }

  Future<void> loadCompositeImages(String uploadFolder) async {
    _isLoading = true;
    notifyListeners();

    try {
      final directory = Directory(uploadFolder);

      if (await directory.exists()) {
        List<File> images = [];

        await for (var entity in directory.list()) {
          if (entity is File) {
            final fileName = path.basename(entity.path).toLowerCase();
            if (fileName.contains('composite') &&
                (fileName.endsWith('.jpg') ||
                    fileName.endsWith('.jpeg') ||
                    fileName.endsWith('.png'))) {
              images.add(entity);
            }
          }
        }

        _compositeImages = images;
        _sortCompositeImages();
      } else {
        _compositeImages = [];
      }
    } catch (e) {
      print('Error loading composite images: $e');
      _compositeImages = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  void setSortOrder(SortOrder order) {
    _sortOrder = order;
    _sortCompositeImages();
    notifyListeners();
  }

  void _sortCompositeImages() {
    if (_sortOrder == SortOrder.newest) {
      _compositeImages.sort(
        (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
      );
    } else {
      _compositeImages.sort(
        (a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()),
      );
    }
  }

  // Helper method to update state and notify listeners
  void setState(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  // Improved GIF creation method with proper awaits
  Future<void> _createSimpleGif({
    required List<String> images,
    required String outputPath,
  }) async {
    _setLoading(true, 'Creating GIF animation', 'Processing images...', null);

    // Ensure we await the result
    final result = await ImageProcessor.createOptimizedGif(
      images: images,
      outputPath: outputPath,
      progressCallback: (progress) {
        _setLoading(
          true,
          'Creating GIF animation',
          'Processing: ${(progress * 100).toInt()}%',
          progress,
        );
      },
    );

    if (result != null) {
      _setLoading(
        true,
        'GIF Created Successfully',
        'File saved to: $outputPath',
        1.0,
      );
      await Future.delayed(const Duration(milliseconds: 500));
    } else {
      _setLoading(
        true,
        'GIF Creation Failed',
        'Could not create animation',
        null,
      );
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  void _clearTakenPhotos() {
    _takenPhotos.clear();
    notifyListeners();
  }
}
