import 'package:flutter/material.dart';
import 'package:photobooth/models/layout_model.dart';
import 'package:photobooth/models/preset_model.dart';
import 'package:photobooth/providers/layout_provider.dart';
import 'package:provider/provider.dart';

class EventModel {
  String name;
  String description;
  String date;
  int layoutId;
  String saveFolder;
  String uploadFolder;
  // Add preset to event model
  PresetModel preset;

  EventModel({
    required this.name,
    required this.description,
    required this.date,
    required this.layoutId,
    required this.saveFolder,
    required this.uploadFolder,
    PresetModel? preset,
  }) : preset = preset ?? PresetModel.defaultPreset();

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      name: json['name'],
      description: json['description'],
      date: json['date'],
      layoutId: json['layoutId'],
      saveFolder: json['saveFolder'],
      uploadFolder: json['uploadFolder'],
      // Parse preset if available
      preset:
          json['preset'] != null
              ? PresetModel.fromJson(json['preset'])
              : PresetModel.defaultPreset(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'date': date,
      'layoutId': layoutId,
      'saveFolder': saveFolder,
      'uploadFolder': uploadFolder,
      // Include preset in event JSON
      'preset': preset.toJson(),
    };
  }

  // Update event preset
  void updatePreset(PresetModel newPreset) {
    preset = newPreset;
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
