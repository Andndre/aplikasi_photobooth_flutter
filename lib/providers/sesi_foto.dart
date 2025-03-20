import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:win32/win32.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';

class SesiFotoProvider with ChangeNotifier {
  final List<File> _takenPhotos = [];
  bool _isLoading = false;
  String _loadingMessage = '';

  List<File> get takenPhotos => _takenPhotos;
  bool get isLoading => _isLoading;
  String get loadingMessage => _loadingMessage;

  void _setLoading(bool isLoading, [String message = '']) {
    _isLoading = isLoading;
    _loadingMessage = message;
    notifyListeners();
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
