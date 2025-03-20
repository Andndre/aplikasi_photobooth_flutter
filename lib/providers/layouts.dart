import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/layouts.dart';

class LayoutsProvider with ChangeNotifier {
  List<Layouts> _layouts = [];
  int _nextId = 1;
  bool _loaded = false;

  List<Layouts> get layouts => _layouts;
  bool get isLoaded => _loaded;

  Layouts getLayoutById(int id) {
    return _layouts.firstWhere((layout) => layout.id == id);
  }

  Future<void> loadLayouts() async {
    if (_loaded) return;

    final prefs = await SharedPreferences.getInstance();
    final layoutsString = prefs.getString('layouts');
    if (layoutsString != null) {
      final List<dynamic> layoutsJson = json.decode(layoutsString);
      _layouts = layoutsJson.map((json) => Layouts.fromJson(json)).toList();
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

  Future<void> addLayout(Layouts layout) async {
    layout.id = _nextId++;
    _layouts.add(layout);
    await _saveToLocalStorage();
    notifyListeners();
  }

  Future<void> editLayout(int index, Layouts layout) async {
    _layouts[index] = layout;
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

  bool layoutExists(int id) {
    if (!_loaded) {
      // If layouts haven't been loaded yet, we can't be sure
      // It's safer to return false and let the UI handle it
      return false;
    }
    return _layouts.any((layout) => layout.id == id);
  }
}
