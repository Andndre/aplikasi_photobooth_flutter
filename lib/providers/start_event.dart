import 'dart:io';
import 'package:flutter/material.dart';

enum SortOrder { newest, oldest }

class StartEventProvider with ChangeNotifier {
  List<File> _compositeImages = [];
  SortOrder _sortOrder = SortOrder.newest;

  List<File> get compositeImages => _compositeImages;
  SortOrder get sortOrder => _sortOrder;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void setSortOrder(SortOrder order) {
    _sortOrder = order;
    _sortImages();
    notifyListeners();
  }

  void _sortImages() {
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

      _compositeImages = images;
      _sortImages();
    }

    _isLoading = false;
    notifyListeners();
  }
}
