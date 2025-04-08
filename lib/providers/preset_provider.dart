import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:photobooth/providers/event_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:photobooth/models/preset_model.dart';
import 'package:photobooth/models/event_model.dart';

class PresetProvider with ChangeNotifier {
  final _uuid = const Uuid();
  List<PresetModel> _savedPresets = [];
  String? _activePresetId;

  List<PresetModel> get savedPresets => _savedPresets;

  PresetModel? get activePreset {
    // Return the preset matching the active preset ID if one exists
    if (_activePresetId != null) {
      try {
        // Detailed debug logs to trace preset retrieval
        print('Looking for active preset with ID: $_activePresetId');
        print(
          'Available preset IDs: ${_savedPresets.map((p) => p.id).toList()}',
        );

        // First attempt to find the preset with the active ID
        final activePreset = _savedPresets.firstWhere(
          (p) => p.id == _activePresetId,
        );
        print('Found active preset: ${activePreset.name}');
        return activePreset;
      } catch (e) {
        print(
          'Warning: Active preset ID $_activePresetId not found in saved presets. Error: $e',
        );
        // Don't return a default here, return null to trigger the fallback below
      }
    } else {
      print('No active preset ID set');
    }

    // If we couldn't find the preset by ID or no active ID is set,
    // return the first preset if available
    if (_savedPresets.isNotEmpty) {
      print('Falling back to first saved preset: ${_savedPresets.first.name}');
      return _savedPresets.first;
    }

    // Return null if no presets are available
    print('No presets available, returning null');
    return null;
  }

  PresetProvider() {
    _loadSavedPresets();
  }

  // Load saved presets from shared preferences
  Future<void> _loadSavedPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final presetsJson = prefs.getString('saved_presets');
    final activeId = prefs.getString('active_preset_id');

    print('Loading saved presets from SharedPreferences');
    print('Active preset ID from prefs: $activeId');

    if (presetsJson != null) {
      try {
        final List<dynamic> decoded = json.decode(presetsJson);
        _savedPresets =
            decoded.map((item) => PresetModel.fromJson(item)).toList();
        _activePresetId = activeId;

        print('Loaded ${_savedPresets.length} presets:');
        for (var preset in _savedPresets) {
          print('  - ${preset.name} (ID: ${preset.id})');
        }

        // Add default preset if none exist
        if (_savedPresets.isEmpty) {
          print('No presets found, adding default preset');
          _addDefaultPreset();
        }
      } catch (e) {
        print('Error loading presets: $e');
        _addDefaultPreset();
      }
    } else {
      print('No saved presets found, adding default preset');
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

  // Updated method to save a preset from an event
  Future<PresetModel> savePresetFromEvent(
    EventModel event, {
    String? newName,
    BuildContext? context,
  }) async {
    final presetId = _uuid.v4();
    final presetName = newName ?? '${event.name} Preset';

    // Get the preset from the event using presetId
    PresetModel? sourcePreset;

    if (context != null) {
      // If context is provided, use it to get the preset
      sourcePreset = event.getPreset(context);
    } else {
      // Otherwise look it up directly
      sourcePreset = getPresetById(event.presetId);
    }

    // Fallback to default preset if not found
    sourcePreset ??= activePreset ?? PresetModel.defaultPreset();

    // Create a new preset based on the event's preset
    final newPreset = sourcePreset.clone(newId: presetId, newName: presetName);

    // Add to saved presets
    _savedPresets.add(newPreset);
    await _savePresets();
    notifyListeners();

    return newPreset;
  }

  // Updated method to apply a preset to an event
  void applyPresetToEvent(EventModel event, String presetId) {
    // Simply update the event's presetId
    event.updatePresetId(presetId);
    notifyListeners();

    // Print debug info
    print('Applied preset ID $presetId to event ${event.name}');
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

  // Set the active preset and also update the current event
  Future<void> setActivePreset(
    String id, {
    BuildContext? context,
    EventModel? currentEvent,
  }) async {
    print('Setting active preset ID to: $id');
    _activePresetId = id;

    // Get the preset being activated to verify it exists
    final preset = getPresetById(id);
    if (preset != null) {
      print('Successfully activated preset: ${preset.name} (ID: $id)');

      // Apply this preset to current event if provided
      if (currentEvent != null) {
        print('Applying preset to event: ${currentEvent.name}');
        currentEvent.updatePresetId(id);

        // Save the event changes if context is provided
        if (context != null) {
          try {
            final eventProvider = Provider.of<EventsProvider>(
              context,
              listen: false,
            );
            await eventProvider.saveEvents();
            print('Updated and saved event with new preset ID: $id');
          } catch (e) {
            print('Error saving event with updated preset: $e');
          }
        }
      }
    } else {
      print(
        'Warning: Activating preset with ID $id that was not found in saved presets',
      );
    }

    await _savePresets();
    notifyListeners();
  }

  // Add a new method to get the actual preset by ID without falling back to the default
  PresetModel? getPresetById(String id) {
    if (id.isEmpty) {
      print('Warning: Attempted to get preset with null or empty ID');
      return null;
    }

    print('Looking for preset with ID: $id');
    print('Available presets: ${_savedPresets.length}');
    print(
      'Available preset IDs: ${_savedPresets.map((p) => '${p.id} (${p.name})').join(', ')}',
    );

    try {
      final preset = _savedPresets.firstWhere((p) => p.id == id);
      print('Found preset: ${preset.name} with ID ${preset.id}');
      return preset;
    } catch (e) {
      print('❌ Preset with ID "$id" not found: $e');

      // Force reload presets from storage if not found - the preset might have been added after initial load
      _reloadPresetsFromStorage().then((_) {
        print('Reloaded presets after failed lookup');
        // Re-check for preset after reload
        try {
          final preset = _savedPresets.firstWhere((p) => p.id == id);
          print('Found preset after reload: ${preset.name}');
        } catch (e) {
          print('Still could not find preset after reload: $e');
        }
      });

      return null;
    }
  }

  // Force reload presets from storage
  Future<void> _reloadPresetsFromStorage() async {
    print('Force reloading presets from storage');
    final prefs = await SharedPreferences.getInstance();
    final presetsJson = prefs.getString('saved_presets');

    if (presetsJson != null) {
      try {
        final List<dynamic> decoded = json.decode(presetsJson);
        _savedPresets =
            decoded.map((item) => PresetModel.fromJson(item)).toList();
        print('Reloaded ${_savedPresets.length} presets');
      } catch (e) {
        print('Error reloading presets: $e');
      }
    }
  }

  // Apply a preset ID to an event
  void applyPresetIdToEvent(EventModel event, String presetId) {
    // Verify the preset exists before assigning it
    final preset = getPresetById(presetId);
    if (preset != null) {
      event.updatePresetId(presetId);
      print(
        'Applied preset "${preset.name}" (ID: $presetId) to event ${event.name}',
      );
    } else {
      print(
        'Warning: Attempted to apply non-existent preset ID $presetId to event ${event.name}',
      );
    }
    notifyListeners();
  }
}
