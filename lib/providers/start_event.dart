import 'dart:io';
import 'package:flutter/material.dart';

class StartEventProvider with ChangeNotifier {
  List<File> _compositeImages = [];

  List<File> get compositeImages => _compositeImages;

  bool _isLoading = false;

  bool get isLoading => _isLoading;

  Future<void> loadCompositeImages(String uploadFolder) async {
    _isLoading = true;
    notifyListeners();

    final directory = Directory(uploadFolder);
    final List<File> images = [];
    if (await directory.exists()) {
      final files = directory.listSync();
      for (var file in files) {
        if (file is File &&
            file.path.contains('composite') &&
            (file.path.endsWith('.png') || file.path.endsWith('.jpg'))) {
          images.add(file);
        }
      }
      images.sort(
        (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
      );
    }

    _compositeImages = images;

    _isLoading = false;
    notifyListeners();
  }
}
