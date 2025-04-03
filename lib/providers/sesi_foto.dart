import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:photobooth/components/dialogs/composite_images_dialog.dart';
import 'package:photobooth/components/dialogs/captured_photos_dialog.dart';
import 'package:photobooth/models/layout_model.dart';
import 'package:photobooth/models/renderables/renderer.dart';
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

  void _setLoading(bool isLoading, [String message = '']) {
    _isLoading = isLoading;
    _loadingMessage = message;
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

    // Wait longer to ensure WhatsApp has completed its operation
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
          ),
    );
  }

  Future<void> generateComposite(
    String uploadFolder,
    String eventName,
    LayoutModel layout,
    BuildContext context,
  ) async {
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

    _setLoading(true, 'Creating composite image and GIF...');

    try {
      // Export the composite image using the layout's exportAsImage method
      final exportedFile = await Renderer.exportLayoutWithImages(
        layout: layout,
        exportPath: compositeImagePath,
        filePaths: _takenPhotos.map((file) => file.path).toList(),
        resolutionMultiplier: 1,
      );

      if (exportedFile != null) {
        print('Composite image created: ${exportedFile.path}');
      } else {
        print('Failed to create composite image');
      }

      // Create GIF from captured photos
      await _createSimpleGif(
        images: _takenPhotos.map((file) => file.path).toList(),
        outputPath: gifPath,
      );

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
    } finally {
      _setLoading(false);
    }
  }

  void _clearTakenPhotos() {
    _takenPhotos.clear();
    notifyListeners();
  }

  Future<void> _createSimpleGif({
    required List<String> images,
    required String outputPath,
  }) async {
    if (images.isEmpty) return;

    try {
      final frames = await compute((Map<String, dynamic> params) {
        final paths = params['imagePaths'] as List<String>;
        return paths.map((imagePath) {
          final image = img.decodeImage(File(imagePath).readAsBytesSync())!;
          return img.copyResize(
            image,
            width: image.width ~/ 3,
            height: image.height ~/ 3,
          );
        }).toList();
      }, {'imagePaths': images});

      final encoder = img.GifEncoder();
      encoder.repeat = 3;
      for (var frame in frames) {
        encoder.addFrame(frame, duration: 50);
      }
      final gif = encoder.finish()!;

      await File(outputPath).writeAsBytes(Uint8List.fromList(gif));
      print('GIF created: $outputPath');
    } catch (e) {
      print('Error creating GIF: $e');
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
}
