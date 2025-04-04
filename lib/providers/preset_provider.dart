import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:photobooth/models/preset_model.dart';
import 'package:photobooth/models/event_model.dart';

class PresetProvider with ChangeNotifier {
  final _uuid = const Uuid();
  List<PresetModel> _savedPresets = [];
  String? _activePresetId;

  List<PresetModel> get savedPresets => _savedPresets;

  PresetModel? get activePreset =>
      _activePresetId != null
          ? _savedPresets.firstWhere(
            (p) => p.id == _activePresetId,
            orElse:
                () =>
                    _savedPresets.isNotEmpty
                        ? _savedPresets.first
                        : PresetModel.defaultPreset(),
          )
          : _savedPresets.isNotEmpty
          ? _savedPresets.first
          : null;

  PresetProvider() {
    _loadSavedPresets();
  }

  // Load saved presets from shared preferences
  Future<void> _loadSavedPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final presetsJson = prefs.getString('saved_presets');
    final activeId = prefs.getString('active_preset_id');

    if (presetsJson != null) {
      try {
        final List<dynamic> decoded = json.decode(presetsJson);
        _savedPresets =
            decoded.map((item) => PresetModel.fromJson(item)).toList();
        _activePresetId = activeId;

        // Add default preset if none exist
        if (_savedPresets.isEmpty) {
          _addDefaultPreset();
        }
      } catch (e) {
        print('Error loading presets: $e');
        _addDefaultPreset();
      }
    } else {
      _addDefaultPreset();
    }

    notifyListeners();
  }

  void _addDefaultPreset() {
    _savedPresets = [PresetModel.defaultPreset()];
    _activePresetId = 'default';
  }

  // Save presets to shared preferences
  Future<void> _savePresets() async {
    final prefs = await SharedPreferences.getInstance();
    final presetsJson = json.encode(
      _savedPresets.map((p) => p.toJson()).toList(),
    );

    await prefs.setString('saved_presets', presetsJson);
    if (_activePresetId != null) {
      await prefs.setString('active_preset_id', _activePresetId!);
    }
  }

  // Save a preset to the list of saved presets
  Future<void> savePreset(PresetModel preset, {bool makeActive = true}) async {
    // If the preset already exists in saved presets, replace it
    final existingIndex = _savedPresets.indexWhere((p) => p.id == preset.id);

    if (existingIndex != -1) {
      _savedPresets[existingIndex] = preset;
    } else {
      _savedPresets.add(preset);
    }

    if (makeActive) {
      _activePresetId = preset.id;
    }

    await _savePresets();
    notifyListeners();
  }

  // Create a new preset (optionally based on an existing one)
  PresetModel createPreset({
    PresetModel? basedOn,
    String? name,
    bool addToSaved = false,
    bool makeActive = false,
  }) {
    final presetId = _uuid.v4();
    final presetName = name ?? 'New Preset';

    // Create a new preset, optionally based on an existing one
    final newPreset =
        basedOn != null
            ? basedOn.clone(newId: presetId, newName: presetName)
            : PresetModel(id: presetId, name: presetName);

    // Optionally add to saved presets
    if (addToSaved) {
      _savedPresets.add(newPreset);

      if (makeActive) {
        _activePresetId = newPreset.id;
      }

      _savePresets();
      notifyListeners();
    }

    return newPreset;
  }

  // Save a preset from an event to the saved presets
  Future<PresetModel> savePresetFromEvent(
    EventModel event, {
    String? newName,
  }) async {
    final presetId = _uuid.v4();
    final presetName = newName ?? '${event.name} Preset';

    // Create a new preset based on the event's preset
    final newPreset = event.preset.clone(newId: presetId, newName: presetName);

    // Add to saved presets
    _savedPresets.add(newPreset);
    await _savePresets();
    notifyListeners();

    return newPreset;
  }

  // Apply a saved preset to an event
  void applyPresetToEvent(EventModel event, String presetId) {
    final preset = _savedPresets.firstWhere(
      (p) => p.id == presetId,
      orElse: () => PresetModel.defaultPreset(),
    );

    event.updatePreset(preset);
    notifyListeners();
  }

  // Update a preset in the saved presets
  Future<void> updatePreset(PresetModel preset) async {
    final index = _savedPresets.indexWhere((p) => p.id == preset.id);
    if (index != -1) {
      _savedPresets[index] = preset;
      await _savePresets();
      notifyListeners();
    }
  }

  // Delete a preset from the saved presets
  Future<void> deletePreset(String id) async {
    // Don't allow deleting the default preset
    if (id == 'default') return;

    _savedPresets.removeWhere((p) => p.id == id);

    // Make sure we don't have an active preset that doesn't exist anymore
    if (_activePresetId == id) {
      _activePresetId =
          _savedPresets.isNotEmpty ? _savedPresets.first.id : 'default';
    }

    await _savePresets();
    notifyListeners();
  }

  // Set the active preset
  Future<void> setActivePreset(String id) async {
    _activePresetId = id;
    await _savePresets();
    notifyListeners();
  }
}
