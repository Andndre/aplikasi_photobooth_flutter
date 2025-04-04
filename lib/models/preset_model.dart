import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

class PresetModel {
  final String id;
  final String name;
  final double brightness;
  final double contrast;
  final double saturation;
  final bool blackAndWhite;
  final double borderWidth;
  final Color borderColor;
  final String? sampleImagePath; // Path to sample image file

  const PresetModel({
    required this.id,
    required this.name,
    this.brightness = 0.0,
    this.contrast = 0.0,
    this.saturation = 0.0,
    this.blackAndWhite = false,
    this.borderWidth = 0.0,
    this.borderColor = Colors.white,
    this.sampleImagePath,
  });

  // Create a default preset with a specific ID
  factory PresetModel.defaultPreset() {
    return const PresetModel(
      id: 'default',
      name: 'Default',
      brightness: 0.0,
      contrast: 0.0,
      saturation: 0.0,
      blackAndWhite: false,
      borderWidth: 0.0,
      borderColor: Colors.white,
      sampleImagePath: null,
    );
  }

  // Create a copy of this model with specified properties changed
  PresetModel copyWith({
    String? name,
    double? brightness,
    double? contrast,
    double? saturation,
    bool? blackAndWhite,
    double? borderWidth,
    Color? borderColor,
    String? sampleImagePath,
  }) {
    return PresetModel(
      id: id,
      name: name ?? this.name,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      blackAndWhite: blackAndWhite ?? this.blackAndWhite,
      borderWidth: borderWidth ?? this.borderWidth,
      borderColor: borderColor ?? this.borderColor,
      sampleImagePath: sampleImagePath ?? this.sampleImagePath,
    );
  }

  // Create a new preset with a new ID but same properties
  PresetModel clone({required String newId, String? newName}) {
    return PresetModel(
      id: newId,
      name: newName ?? name,
      brightness: brightness,
      contrast: contrast,
      saturation: saturation,
      blackAndWhite: blackAndWhite,
      borderWidth: borderWidth,
      borderColor: borderColor,
      sampleImagePath: sampleImagePath,
    );
  }

  // Convert model to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'brightness': brightness,
      'contrast': contrast,
      'saturation': saturation,
      'blackAndWhite': blackAndWhite,
      'borderWidth': borderWidth,
      'borderColor': borderColor.value,
      'sampleImagePath': sampleImagePath,
    };
  }

  // Create model from JSON map
  factory PresetModel.fromJson(Map<String, dynamic> json) {
    return PresetModel(
      id: json['id'] ?? 'default',
      name: json['name'] ?? 'Default',
      brightness: json['brightness']?.toDouble() ?? 0.0,
      contrast: json['contrast']?.toDouble() ?? 0.0,
      saturation: json['saturation']?.toDouble() ?? 0.0,
      blackAndWhite: json['blackAndWhite'] ?? false,
      borderWidth: json['borderWidth']?.toDouble() ?? 0.0,
      borderColor:
          json['borderColor'] != null
              ? Color(json['borderColor'])
              : Colors.white,
      sampleImagePath: json['sampleImagePath'],
    );
  }

  // Helper method to serialize to string
  String toJsonString() {
    return jsonEncode(toJson());
  }

  // Helper method to deserialize from string
  static PresetModel fromJsonString(String jsonString) {
    return PresetModel.fromJson(jsonDecode(jsonString));
  }

  // Check if sample image exists
  bool get hasSampleImage =>
      sampleImagePath != null && File(sampleImagePath!).existsSync();

  // Override == operator for value equality
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PresetModel &&
        other.id == id &&
        other.name == name &&
        other.brightness == brightness &&
        other.contrast == contrast &&
        other.saturation == saturation &&
        other.blackAndWhite == blackAndWhite &&
        other.borderWidth == borderWidth &&
        other.borderColor.value == borderColor.value &&
        other.sampleImagePath == sampleImagePath;
  }

  // Override hashCode for value equality
  @override
  int get hashCode => Object.hash(
    id,
    name,
    brightness,
    contrast,
    saturation,
    blackAndWhite,
    borderWidth,
    borderColor.value,
    sampleImagePath,
  );
}
