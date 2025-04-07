import 'package:flutter/material.dart';
import 'package:photobooth/models/layout_model.dart';
import 'package:photobooth/models/preset_model.dart';
import 'package:photobooth/providers/layout_provider.dart';
import 'package:photobooth/providers/preset_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart'; // Add UUID import

class EventModel {
  // Add id field using UUID
  final String id;
  String name;
  String description;
  String date;
  int layoutId;
  String saveFolder;
  String uploadFolder;
  // Store presetId instead of complete preset
  String presetId;

  // Cache for performance
  PresetModel? _cachedPreset;

  EventModel({
    String? id, // Make id optional with default generation
    required this.name,
    required this.description,
    required this.date,
    required this.layoutId,
    required this.saveFolder,
    required this.uploadFolder,
    String? presetId,
    // For backward compatibility
    PresetModel? preset,
  }) : id = id ?? const Uuid().v4(), // Generate UUID if not provided
       presetId = presetId ?? (preset?.id ?? 'default');

  factory EventModel.fromJson(Map<String, dynamic> json) {
    // Handle both new format (presetId) and old format (preset object)
    String presetId = 'default';

    if (json['presetId'] != null) {
      // New format with ID
      presetId = json['presetId'];
    } else if (json['preset'] != null) {
      // Old format with complete preset object
      try {
        final preset = PresetModel.fromJson(json['preset']);
        presetId = preset.id;
      } catch (e) {
        print('Error parsing preset: $e');
      }
    }

    return EventModel(
      id: json['id'] ?? const Uuid().v4(), // Use UUID if no id in JSON
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      date: json['date'] ?? '',
      layoutId: json['layoutId'] ?? 0,
      saveFolder: json['saveFolder'] ?? '',
      uploadFolder: json['uploadFolder'] ?? '',
      presetId: presetId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id, // Include id in JSON
      'name': name,
      'description': description,
      'date': date,
      'layoutId': layoutId,
      'saveFolder': saveFolder,
      'uploadFolder': uploadFolder,
      // Store only the preset ID
      'presetId': presetId,
    };
  }

  // Get the preset by ID from PresetProvider
  PresetModel getPreset(BuildContext context) {
    // Add assertions
    assert(context != null, 'Context is null in getPreset');

    print('Event [${name}] getting preset with ID: "$presetId"');

    // Return cached preset if available and ID matches
    if (_cachedPreset != null && _cachedPreset!.id == presetId) {
      print(
        '✅ Using cached preset: ${_cachedPreset!.name} (ID: ${_cachedPreset!.id})',
      );
      return _cachedPreset!;
    }

    try {
      // Get preset provider
      final presetProvider = Provider.of<PresetProvider>(
        context,
        listen: false,
      );
      assert(presetProvider != null, 'PresetProvider is null');
      print('Looking up preset from provider');

      // First, try to get the preset by ID from the provider
      final preset = presetProvider.getPresetById(presetId);

      if (preset != null) {
        print('✅ Found preset by ID lookup: ${preset.name}');
        _cachedPreset = preset;
        return preset;
      }

      print('⚠️ Preset not found by ID, trying active preset');

      // If not found by ID, try active preset
      final activePreset = presetProvider.activePreset;
      if (activePreset != null) {
        print('✅ Using active preset as fallback: ${activePreset.name}');
        // Update the presetId to match what we're actually using
        presetId = activePreset.id;
        _cachedPreset = activePreset;
        return activePreset;
      }

      // If still null, use default preset
      print('⚠️ No active preset, creating default preset');
      final defaultPreset = PresetModel.defaultPreset();
      _cachedPreset = defaultPreset;
      return defaultPreset;
    } catch (e) {
      print('❌ Error getting preset: $e');

      // Create and return a default preset as fallback
      final defaultPreset = PresetModel.defaultPreset();
      _cachedPreset = defaultPreset;
      return defaultPreset;
    }
  }

  // Getter for backward compatibility
  PresetModel? get preset => _cachedPreset;

  // Update the preset ID for this event
  void updatePresetId(String newPresetId) {
    presetId = newPresetId;
    _cachedPreset = null; // Clear cache
  }

  // For backward compatibility
  void updatePreset(PresetModel newPreset) {
    presetId = newPreset.id;
    _cachedPreset = newPreset; // Cache the new preset
  }

  LayoutModel getLayout(BuildContext context) {
    return Provider.of<LayoutsProvider>(
      context,
      listen: false,
    ).layouts.firstWhere((layout) => layout.id == layoutId);
  }

  bool hasValidLayout(BuildContext context) {
    final layoutsProvider = Provider.of<LayoutsProvider>(
      context,
      listen: false,
    );
    return layoutsProvider.layouts.any((layout) => layout.id == layoutId);
  }
}
