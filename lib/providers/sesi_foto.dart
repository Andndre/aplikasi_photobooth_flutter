import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:win32/win32.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'package:aplikasi_photobooth_flutter/pages/start_event.dart';
import 'dart:ui' as ui;

class SesiFotoProvider with ChangeNotifier {
  final List<File> _takenPhotos = [];
  bool _isLoading = false;
  String _loadingMessage = '';
  WindowInfo? _windowToCapture;

  List<File> get takenPhotos => _takenPhotos;
  bool get isLoading => _isLoading;
  String get loadingMessage => _loadingMessage;
  WindowInfo? get windowToCapture => _windowToCapture;

  void _setLoading(bool isLoading, [String message = '']) {
    _isLoading = isLoading;
    _loadingMessage = message;
    notifyListeners();
  }

  void setWindowToCapture(WindowInfo? window) {
    _windowToCapture = window;
    notifyListeners();
  }

  // Simplified capture window function with better error handling
  Future<Map<String, dynamic>?> captureWindowWithSize() async {
    if (_windowToCapture == null) return null;

    int hwnd = _windowToCapture!.hwnd;

    // Check if window is still valid
    if (IsWindow(hwnd) == 0) return null;

    // Get window dimensions
    final rect = calloc<RECT>();
    if (GetWindowRect(hwnd, rect) == 0) {
      calloc.free(rect);
      return null;
    }

    int width = rect.ref.right - rect.ref.left;
    int height = rect.ref.bottom - rect.ref.top;

    // Check for valid dimensions
    if (width <= 0 || height <= 0 || width > 10000 || height > 10000) {
      calloc.free(rect);
      return null;
    }

    // Create DC for window and compatible DC for bitmap
    final hdcWindow = GetDC(hwnd);
    if (hdcWindow == 0) {
      calloc.free(rect);
      return null;
    }

    final hdcMemDC = CreateCompatibleDC(hdcWindow);
    if (hdcMemDC == 0) {
      ReleaseDC(hwnd, hdcWindow);
      calloc.free(rect);
      return null;
    }

    // Create compatible bitmap
    final hbmScreen = CreateCompatibleBitmap(hdcWindow, width, height);
    if (hbmScreen == 0) {
      DeleteDC(hdcMemDC);
      ReleaseDC(hwnd, hdcWindow);
      calloc.free(rect);
      return null;
    }

    final hbmOld = SelectObject(hdcMemDC, hbmScreen);

    // Use BitBlt which is more stable for frequent captures
    BitBlt(hdcMemDC, 0, 0, width, height, hdcWindow, 0, 0, SRCCOPY);

    // Create BITMAPINFOHEADER structure
    final bi = calloc<BITMAPINFOHEADER>();
    ZeroMemory(bi, sizeOf<BITMAPINFOHEADER>());
    bi.ref.biSize = sizeOf<BITMAPINFOHEADER>();
    bi.ref.biWidth = width;
    bi.ref.biHeight = -height; // Negative for top-down DIB
    bi.ref.biPlanes = 1;
    bi.ref.biBitCount = 32;
    bi.ref.biCompression = BI_RGB;

    // Calculate the size of the DIB
    final dwBmpSize = ((width * 32 + 31) ~/ 32) * 4 * height;

    // Allocate memory for the bitmap bits
    final lpbitmap = calloc<Uint8>(dwBmpSize);

    // Get the bitmap bits
    final dibResult = GetDIBits(
      hdcMemDC,
      hbmScreen,
      0,
      height,
      lpbitmap,
      bi.cast(),
      DIB_RGB_COLORS,
    );

    if (dibResult == 0) {
      // Clean up on failure
      SelectObject(hdcMemDC, hbmOld);
      DeleteObject(hbmScreen);
      DeleteDC(hdcMemDC);
      ReleaseDC(hwnd, hdcWindow);
      calloc.free(rect);
      calloc.free(bi);
      calloc.free(lpbitmap);
      return null;
    }

    try {
      // Convert bitmap data to Dart Uint8List
      final bitmapBytes = Uint8List.fromList(lpbitmap.asTypedList(dwBmpSize));

      // Clean up resources before image processing to reduce memory usage
      SelectObject(hdcMemDC, hbmOld);
      DeleteObject(hbmScreen);
      DeleteDC(hdcMemDC);
      ReleaseDC(hwnd, hdcWindow);
      calloc.free(rect);
      calloc.free(bi);
      calloc.free(lpbitmap);

      // Use the img package for more stable image processing
      final image = img.Image(width: width, height: height);

      // Convert BGRA to RGBA while copying to image
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final i = (y * width + x) * 4;
          final b = bitmapBytes[i];
          final g = bitmapBytes[i + 1];
          final r = bitmapBytes[i + 2];
          final a = bitmapBytes[i + 3];

          // Set pixel directly in the image
          image.setPixel(x, y, img.ColorRgba8(r, g, b, a));
        }
      }

      // Encode to PNG format which is more compatible with Image.memory
      final pngBytes = Uint8List.fromList(img.encodePng(image));

      return {'bytes': pngBytes, 'width': width, 'height': height};
    } catch (e) {
      print('Error processing image: $e');
      return null;
    }
  }

  // Simplified captureWindow function
  Future<Uint8List?> captureWindow() async {
    final result = await captureWindowWithSize();
    return result?['bytes'] as Uint8List?;
  }

  Future<void> takePhoto(
    String saveFolder,
    String uploadFolder,
    String eventName,
    List<List<int>> coordinates,
    String basePhotoPath,
    BuildContext context,
  ) async {
    final hwnd = FindWindowEx(0, 0, nullptr, TEXT('Remote'));
    if (hwnd == 0) {
      print("Error: Imaging Edge Remote tidak ditemukan!");
      return;
    }

    SetForegroundWindow(hwnd);
    await Future.delayed(const Duration(milliseconds: 300));

    // Simulate key press for '1'
    final input = calloc<INPUT>();
    input.ref.type = INPUT_KEYBOARD;
    input.ref.ki.wVk = VK_1;
    SendInput(1, input, sizeOf<INPUT>());
    await Future.delayed(const Duration(seconds: 1));
    input.ref.ki.dwFlags = KEYEVENTF_KEYUP;
    SendInput(1, input, sizeOf<INPUT>());
    calloc.free(input);

    print("Foto diambil.");

    // Back to the main window
    await Future.delayed(const Duration(seconds: 3));

    // Get the latest photo from the save folder
    final directory = Directory(saveFolder);
    if (await directory.exists()) {
      final files = directory.listSync().whereType<File>().toList();
      files.sort(
        (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
      );
      if (files.isNotEmpty) {
        _takenPhotos.add(files.first);
        notifyListeners();
      }
    }

    SetForegroundWindow(
      FindWindowEx(0, 0, nullptr, TEXT('aplikasi_photobooth_flutter')),
    );

    print("Foto disimpan. Jumlah foto: ${_takenPhotos.length}");

    // If all photos are taken, copy them to the upload folder and create composite image and GIF
    if (_takenPhotos.length == coordinates.length) {
      final existingFiles =
          Directory(uploadFolder).listSync().whereType<File>().toList();
      int maxIndex = 0;
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
          } else {
            final index = int.parse(fileName.split('_').last.split('.').first);
            if (index > maxIndex) {
              maxIndex = index;
            }
          }
        } catch (e) {
          continue;
        }
      }

      // if taken photos are same as layout, create composite image and GIF
      for (var i = 0; i < _takenPhotos.length; i++) {
        final photo = _takenPhotos[i];
        final newFileName = 'Luminara_${eventName}_${maxIndex + i + 1}.jpg';
        final newFilePath = path.join(uploadFolder, newFileName);
        photo.copySync(newFilePath);
        print('Foto ${photo.path} disalin ke $newFilePath');
      }

      final compositeImagePath = path.join(
        uploadFolder,
        'Luminara_${eventName}_${maxCompositeIndex + 2}_composite.jpg',
      );

      final gifPath = path.join(
        uploadFolder,
        'Luminara_${eventName}_${maxCompositeIndex + 2}_gif.gif',
      );

      // Use compute to run the composite image and GIF creation in separate isolates
      _setLoading(true, 'Creating composite image and GIF...');
      await Future.wait([
        compute(_createCompositeImage, {
          'basePhotoPath': basePhotoPath,
          'images': _takenPhotos.map((file) => file.path).toList(),
          'coordinates': coordinates,
          'outputPath': compositeImagePath,
        }),
        compute(_createGif, {
          'images': _takenPhotos.map((file) => file.path).toList(),
          'outputPath': gifPath,
        }),
      ]);
      _setLoading(false);

      _takenPhotos.clear();
      notifyListeners();

      if (context.mounted) {
        // pop the current page
        Navigator.of(context).pop();
      }
    }
  }

  static Future<void> _createCompositeImage(Map<String, dynamic> params) async {
    final basePhotoPath = params['basePhotoPath'] as String;
    final images = (params['images'] as List).cast<String>();
    final coordinates =
        (params['coordinates'] as List)
            .map((coords) => (coords as List).cast<int>())
            .toList();
    final outputPath = params['outputPath'] as String;

    final basePhoto = img.decodeImage(File(basePhotoPath).readAsBytesSync())!;
    final compositeImage = basePhoto.clone();

    for (var i = 0; i < images.length; i++) {
      print('Composite image $i');
      final photo = img.decodeImage(File(images[i]).readAsBytesSync())!;
      final coords = coordinates[i];
      img.compositeImage(
        compositeImage,
        photo,
        dstX: coords[0],
        dstY: coords[1],
        dstW: coords[2],
        dstH: coords[3],
      );
    }

    img.compositeImage(compositeImage, basePhoto, dstX: 0, dstY: 0);
    File(outputPath).writeAsBytesSync(img.encodeJpg(compositeImage));

    print('Composite image created: $outputPath');
  }

  static Future<void> _createGif(Map<String, dynamic> params) async {
    final images = (params['images'] as List).cast<String>();
    final outputPath = params['outputPath'] as String;

    final frames =
        images.map((imagePath) {
          final decodedImage =
              img.decodeImage(File(imagePath).readAsBytesSync())!;
          return img.copyResize(
            decodedImage,
            width: decodedImage.width ~/ 3,
            height: decodedImage.height ~/ 3,
          );
        }).toList();

    final gif = encodeGifAnimation(frames, repeat: 3);
    File(outputPath).writeAsBytesSync(Uint8List.fromList(gif));

    print('GIF created: $outputPath');
  }

  static Uint8List encodeGifAnimation(
    List<img.Image> frames, {
    required int repeat,
  }) {
    final encoder = img.GifEncoder();
    encoder.repeat = repeat;
    for (var frame in frames) {
      encoder.addFrame(frame, duration: 50);
    }
    return encoder.finish()!;
  }
}
