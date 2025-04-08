import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
import 'package:photobooth/services/screen_capture_service.dart';

class CompositeJob {
  final String eventName;
  final String uploadFolder;
  final DateTime startedAt;
  bool isComplete = false;
  bool hasError = false;
  String message = '';
  String subMessage = '';
  double? progressValue;
  String? errorMessage;

  CompositeJob({
    required this.eventName,
    required this.uploadFolder,
    required this.startedAt,
    this.message = 'Starting composite generation...',
    this.subMessage = 'Preparing...',
    this.progressValue = 0.0,
  });
}

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

  // Add list to track multiple composite jobs
  final List<CompositeJob> _compositeJobs = [];

  // Getters
  List<CompositeJob> get compositeJobs => _compositeJobs;
  bool get hasActiveCompositeJobs =>
      _compositeJobs.any((job) => !job.isComplete);

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

    final hwnd = FindWindowEx(0, 0, nullptr, TEXT('Remote'));
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

          try {
            // Make sure the old file is not locked
            if (await oldPhoto.exists()) {
              try {
                await oldPhoto.delete();
              } catch (e) {
                print('Failed to delete old photo: $e');
                // Continue anyway
              }
            }

            // Copy the new photo to replace the old one
            await newPhoto.copy(oldPath);

            // Explicitly recreate the file reference to avoid cache issues
            _takenPhotos[index] = File(oldPath);

            // Ensure the file exists and is readable
            final newFile = _takenPhotos[index];
            if (!await newFile.exists()) {
              print('Warning: New file does not exist after copy: $oldPath');
            } else {
              // Force read to verify file is accessible
              await newFile.readAsBytes();
            }

            // Reset retake index before showing the dialog
            final savedRetakeIndex = _retakePhotoIndex;
            _retakePhotoIndex = null;

            // Force refresh all File references to clear any cache
            for (int i = 0; i < _takenPhotos.length; i++) {
              _takenPhotos[i] = File(_takenPhotos[i].path);
            }

            // Notify listeners before showing the dialog
            notifyListeners();

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
          } catch (e) {
            print('Error during photo retake: $e');
            // If there was an error, reset retake index
            _retakePhotoIndex = null;
            notifyListeners();
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

    // Clear Flutter's image cache to force reload of all images
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    // Force update with notifyListeners to ensure latest images are used in the dialog
    notifyListeners();

    // Add a small delay to ensure the UI refreshes
    await Future.delayed(const Duration(milliseconds: 100));

    await showDialog(
      context: context,
      barrierDismissible: false, // The WillPopScope will handle dismissals
      builder:
          (dialogContext) => CapturedPhotosDialog(
            // Use timestamp in key to guarantee fresh instance
            key: ValueKey(
              'captured-photos-${DateTime.now().millisecondsSinceEpoch}',
            ),
            photos:
                _takenPhotos
                    .map((file) => File(file.path))
                    .toList(), // Force new File instances
            onRetake: (index) {
              // Set the retake index
              setRetakePhotoIndex(index);
              // Close the dialog using the dialog's context
              Navigator.of(dialogContext).pop();
            },
            onConfirm: () {
              // Close the dialog first
              Navigator.of(dialogContext).pop();

              // Start the composite generation
              Future.microtask(() {
                Future.delayed(
                  const Duration(milliseconds: 300),
                  () => generateComposite(
                    uploadFolder,
                    eventName,
                    layout,
                    context,
                  ),
                );
              });
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
    // Create a new job and add it to the list
    final newJob = CompositeJob(
      eventName: eventName,
      uploadFolder: uploadFolder,
      startedAt: DateTime.now(),
    );

    _compositeJobs.insert(0, newJob); // Add to the beginning of the list
    notifyListeners();

    assert(uploadFolder.isNotEmpty, 'Upload folder is empty');
    assert(eventName.isNotEmpty, 'Event name is empty');

    // Start processing
    try {
      // Copy original photos for processing - do this immediately to free up takenPhotos
      final List<File> photosCopy = List.from(_takenPhotos);

      // Clear taken photos to allow a new session to start immediately
      _clearTakenPhotos();

      _updateCompositeJob(
        newJob,
        message: 'Processing photos with preset...',
        subMessage: 'Preparing...',
        progress: 0.05,
      );

      if (!context.mounted) return;
      final eventProvider = Provider.of<EventsProvider>(context, listen: false);
      final presetProvider = Provider.of<PresetProvider>(
        context,
        listen: false,
      );

      // Get the active preset from PresetProvider
      final activePreset = presetProvider.activePreset;
      final event = eventProvider.events.firstWhereOrNull(
        (e) => e.name == eventName,
      );

      // Use the active preset and update it to the event
      PresetModel? eventPreset = activePreset;

      // If we have an event and the active preset isn't default, update the event's preset ID
      if (event != null &&
          activePreset != null &&
          activePreset.id != 'default') {
        // Update the event to use the active preset
        event.updatePresetId(activePreset.id);
        // Save this change to SharedPreferences
        await eventProvider.saveEvents();
        print(
          'Updated event ${event.name} to use preset ${activePreset.name} (ID: ${activePreset.id})',
        );
      }

      // Final fallback to default preset
      eventPreset ??= PresetModel.defaultPreset();

      _updateCompositeJob(
        newJob,
        message: 'Applying preset "${eventPreset.name}"',
        subMessage: 'Processing photos...',
        progress: 0.1,
      );

      // Use the improved batchProcessImagesWithProgress method
      List<File> processedPhotos =
          await ImageProcessor.batchProcessImagesWithProgress(
            photosCopy,
            eventPreset,
            (progress, message) {
              _updateCompositeJob(
                newJob,
                message: 'Processing photos',
                subMessage: message,
                progress: 0.1 + (progress * 0.4), // Scale progress to 10-50%
              );
            },
          );

      // Find existing files to determine next index
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

      // Save individual processed photos
      _updateCompositeJob(
        newJob,
        message: 'Photos processed successfully',
        subMessage: 'Saving individual photos...',
        progress: 0.5,
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
        _updateCompositeJob(
          newJob,
          message: 'Saving individual processed photos',
          subMessage: 'Saved ${i + 1} of ${processedPhotos.length}',
          progress: 0.5 + ((i + 1) / processedPhotos.length * 0.1),
        );
      }

      // Start GIF creation
      _updateCompositeJob(
        newJob,
        message: 'Creating composite images',
        subMessage: 'Starting GIF creation...',
        progress: 0.6,
      );

      // Start gif creation but don't await it yet
      final gifFuture = ImageProcessor.createOptimizedGif(
        images: processedPhotos.map((file) => file.path).toList(),
        outputPath: gifPath,
        progressCallback: (progress) {
          _updateCompositeJob(
            newJob,
            message: 'Creating GIF animation',
            subMessage: 'Optimizing frames: ${(progress * 100).toInt()}%',
            progress: 0.6 + (progress * 0.2),
          );
        },
      );

      // Create the composite image
      _updateCompositeJob(
        newJob,
        message: 'Creating composite image',
        subMessage: 'Rendering layout...',
        progress: 0.8,
      );

      // Use a single compute call here, not nested inside another compute
      File? exportedFile;
      try {
        exportedFile = await Renderer.exportLayoutWithImages(
          layout: layout,
          exportPath: compositeImagePath,
          filePaths: processedPhotos.map((file) => file.path).toList(),
          resolutionMultiplier: 1,
        );
      } catch (e) {
        print('Error creating composite: $e');
      }

      if (exportedFile != null) {
        _updateCompositeJob(
          newJob,
          message: 'Composite image created successfully',
          subMessage: 'Waiting for GIF creation to complete...',
          progress: 0.9,
        );
      } else {
        _updateCompositeJob(
          newJob,
          message: 'Error creating composite image',
          subMessage: 'Continuing with GIF creation...',
          progress: 0.9,
        );
      }

      // Wait for GIF to complete
      _updateCompositeJob(
        newJob,
        message: 'Finalizing GIF animation',
        subMessage: 'Please wait...',
        progress: 0.95,
      );

      final gifFile = await gifFuture;

      if (gifFile != null) {
        _updateCompositeJob(
          newJob,
          message: 'Completed Successfully',
          subMessage: 'All images generated successfully',
          progress: 1.0,
          isComplete: true,
        );
        // Notify user of successful completion
        // if (context.mounted) {
        //   ProgressNotifier.showJobCompletedNotification(context, newJob);
        // }
      } else {
        _updateCompositeJob(
          newJob,
          message: 'Completed with Warnings',
          subMessage: 'GIF creation failed, composite image was created',
          progress: 1.0,
          isComplete: true,
        );

        // Notify user of completion with warnings
        // if (context.mounted) {
        //   ProgressNotifier.showJobCompletedNotification(context, newJob);
        // }
      }

      // Wait a moment before showing the dialog
      await Future.delayed(const Duration(seconds: 1));

      // Remove job from list after a delay
      await Future.delayed(const Duration(seconds: 10));
      _compositeJobs.remove(newJob);
      notifyListeners();
    } catch (e) {
      print('Error creating composite image or GIF: $e');
      _updateCompositeJob(
        newJob,
        message: 'Error processing images',
        subMessage: e.toString(),
        progress: 1.0,
        isComplete: true,
        hasError: true,
        errorMessage: e.toString(),
      );

      // Notify user of error
      // if (context.mounted) {
      //   ProgressNotifier.showJobCompletedNotification(context, newJob);
      // }

      // Keep error jobs visible longer
      await Future.delayed(const Duration(seconds: 30));
      _compositeJobs.remove(newJob);
      notifyListeners();
    }
  }

  void _updateCompositeJob(
    CompositeJob job, {
    String? message,
    String? subMessage,
    double? progress,
    bool? isComplete,
    bool? hasError,
    String? errorMessage,
  }) {
    if (message != null) job.message = message;
    if (subMessage != null) job.subMessage = subMessage;
    if (progress != null) job.progressValue = progress;
    if (isComplete != null) job.isComplete = isComplete;
    if (hasError != null) job.hasError = hasError;
    if (errorMessage != null) job.errorMessage = errorMessage;
    notifyListeners();
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

  void setState(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  // Improved GIF creation method with proper awaits
  // Future<void> _createSimpleGif({
  //   required List<String> images,
  //   required String outputPath,
  // }) async {
  //   _setLoading(true, 'Creating GIF animation', 'Processing images...', null);

  //   // Ensure we await the result
  //   final result = await ImageProcessor.createOptimizedGif(
  //     images: images,
  //     outputPath: outputPath,
  //     progressCallback: (progress) {
  //       _setLoading(
  //         true,
  //         'Creating GIF animation',
  //         'Processing: ${(progress * 100).toInt()}%',
  //         progress,
  //       );
  //     },
  //   );

  //   if (result != null) {
  //     _setLoading(
  //       true,
  //       'GIF Created Successfully',
  //       'File saved to: $outputPath',
  //       1.0,
  //     );
  //     await Future.delayed(const Duration(milliseconds: 500));
  //   } else {
  //     _setLoading(
  //       true,
  //       'GIF Creation Failed',
  //       'Could not create animation',
  //       null,
  //     );
  //     await Future.delayed(const Duration(seconds: 1));
  //   }
  // }

  // Make this public so it can be called from outside
  void clearTakenPhotos() {
    _takenPhotos.clear();
    notifyListeners();
  }

  // Keep _clearTakenPhotos as an alias for compatibility
  void _clearTakenPhotos() {
    clearTakenPhotos();
  }
}
