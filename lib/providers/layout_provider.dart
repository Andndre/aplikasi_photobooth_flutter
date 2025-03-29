import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:photobooth/models/layout_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LayoutsProvider with ChangeNotifier {
  List<LayoutModel> _layouts = [];
  bool _loaded = false;
  int _nextId = 1;

  List<LayoutModel> get layouts => _layouts;
  bool get isLoaded => _loaded;

  LayoutModel? getLayoutById(int id) {
    return _layouts.firstWhereOrNull((layout) => layout.id == id);
  }

  Future<void> loadLayouts() async {
    if (_loaded) return;

    final prefs = await SharedPreferences.getInstance();
    final layoutsString = prefs.getString('layouts');
    if (layoutsString != null) {
      final List<dynamic> layoutsJson = json.decode(layoutsString);
      _layouts = layoutsJson.map((json) => LayoutModel.fromJson(json)).toList();
      if (_layouts.isNotEmpty) {
        _nextId =
            _layouts
                .map((layout) => layout.id)
                .reduce((a, b) => a > b ? a : b) +
            1;
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> addLayout(LayoutModel newLayout) async {
    newLayout.id = _nextId++;
    _layouts.add(newLayout);
    await _saveToLocalStorage();
    notifyListeners();
  }

  Future<void> removeLayout(int index) async {
    _layouts.removeAt(index);
    await _saveToLocalStorage();
    notifyListeners();
  }

  Future<void> _saveToLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final layoutsString = json.encode(
      _layouts.map((layout) => layout.toJson()).toList(),
    );
    prefs.setString('layouts', layoutsString);
  }

  Future<void> editLayout(int index, LayoutModel layout) async {
    _layouts[index] = layout;
    await _saveToLocalStorage();
    notifyListeners();
  }

  layoutExists(int id) {
    if (!_loaded) {
      return false;
    }
    return _layouts.any((layout) => layout.id == id);
  }
}
