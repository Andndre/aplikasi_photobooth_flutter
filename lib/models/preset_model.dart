import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

// Kelas untuk menyimpan titik kurva beserta handle-nya
class CurvePointData {
  final Offset point;
  final Offset? inHandle; // handle masuk (kiri)
  final Offset? outHandle; // handle keluar (kanan)

  const CurvePointData({required this.point, this.inHandle, this.outHandle});

  Map<String, dynamic> toJson() {
    return {
      'x': point.dx,
      'y': point.dy,
      'inX': inHandle?.dx,
      'inY': inHandle?.dy,
      'outX': outHandle?.dx,
      'outY': outHandle?.dy,
    };
  }

  factory CurvePointData.fromJson(Map<String, dynamic> json) {
    return CurvePointData(
      point: Offset(json['x']?.toDouble() ?? 0.0, json['y']?.toDouble() ?? 0.0),
      inHandle:
          json['inX'] != null && json['inY'] != null
              ? Offset(json['inX'].toDouble(), json['inY'].toDouble())
              : null,
      outHandle:
          json['outX'] != null && json['outY'] != null
              ? Offset(json['outX'].toDouble(), json['outY'].toDouble())
              : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CurvePointData &&
        other.point == point &&
        other.inHandle == inHandle &&
        other.outHandle == outHandle;
  }

  @override
  int get hashCode => Object.hash(point, inHandle, outHandle);
}

class PresetModel {
  final String id;
  final String name;
  // Original adjustments
  final double brightness;
  final double contrast;
  final double saturation;
  final bool blackAndWhite;
  final double borderWidth;
  final Color borderColor;
  final String? sampleImagePath;

  // Lightroom-like adjustments
  final double temperature; // Cool to warm (-1.0 to 1.0)
  final double tint; // Green to magenta (-1.0 to 1.0)
  final double exposure; // Darker to brighter (-1.0 to 1.0)
  final double highlights; // Reduce to increase (-1.0 to 1.0)
  final double shadows; // Darken to brighten (-1.0 to 1.0)
  final double whites; // Reduce to increase (-1.0 to 1.0)
  final double blacks; // Increase to reduce (-1.0 to 1.0)

  // Color Mixer adjustments
  final double redHue;
  final double redSaturation;
  final double redLuminance;
  final double greenHue;
  final double greenSaturation;
  final double greenLuminance;
  final double blueHue;
  final double blueSaturation;
  final double blueLuminance;

  // Tone Curve adjustments
  final List<CurvePointData> rgbCurvePoints;
  final List<CurvePointData> redCurvePoints;
  final List<CurvePointData> greenCurvePoints;
  final List<CurvePointData> blueCurvePoints;

  // Legacy tone curve points (untuk kompatibilitas)
  List<Offset> get rgbCurvePointsLegacy =>
      rgbCurvePoints.map((cp) => cp.point).toList();
  List<Offset> get redCurvePointsLegacy =>
      redCurvePoints.map((cp) => cp.point).toList();
  List<Offset> get greenCurvePointsLegacy =>
      greenCurvePoints.map((cp) => cp.point).toList();
  List<Offset> get blueCurvePointsLegacy =>
      blueCurvePoints.map((cp) => cp.point).toList();

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
    // Initialize new properties with default values
    this.temperature = 0.0,
    this.tint = 0.0,
    this.exposure = 0.0,
    this.highlights = 0.0,
    this.shadows = 0.0,
    this.whites = 0.0,
    this.blacks = 0.0,
    // Color mixer defaults
    this.redHue = 0.0,
    this.redSaturation = 0.0,
    this.redLuminance = 0.0,
    this.greenHue = 0.0,
    this.greenSaturation = 0.0,
    this.greenLuminance = 0.0,
    this.blueHue = 0.0,
    this.blueSaturation = 0.0,
    this.blueLuminance = 0.0,
    // Tone curve defaults dengan handle
    this.rgbCurvePoints = const [
      CurvePointData(point: Offset(0, 256)),
      CurvePointData(point: Offset(256, 0)),
    ],
    this.redCurvePoints = const [
      CurvePointData(point: Offset(0, 256)),
      CurvePointData(point: Offset(256, 0)),
    ],
    this.greenCurvePoints = const [
      CurvePointData(point: Offset(0, 256)),
      CurvePointData(point: Offset(256, 0)),
    ],
    this.blueCurvePoints = const [
      CurvePointData(point: Offset(0, 256)),
      CurvePointData(point: Offset(256, 0)),
    ],
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
      temperature: 0.0,
      tint: 0.0,
      exposure: 0.0,
      highlights: 0.0,
      shadows: 0.0,
      whites: 0.0,
      blacks: 0.0,
      // Color mixer defaults
      redHue: 0.0,
      redSaturation: 0.0,
      redLuminance: 0.0,
      greenHue: 0.0,
      greenSaturation: 0.0,
      greenLuminance: 0.0,
      blueHue: 0.0,
      blueSaturation: 0.0,
      blueLuminance: 0.0,
      // Tone curve defaults
      rgbCurvePoints: [
        CurvePointData(point: Offset(0, 256)),
        CurvePointData(point: Offset(256, 0)),
      ],
      redCurvePoints: [
        CurvePointData(point: Offset(0, 256)),
        CurvePointData(point: Offset(256, 0)),
      ],
      greenCurvePoints: [
        CurvePointData(point: Offset(0, 256)),
        CurvePointData(point: Offset(256, 0)),
      ],
      blueCurvePoints: [
        CurvePointData(point: Offset(0, 256)),
        CurvePointData(point: Offset(256, 0)),
      ],
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
    double? temperature,
    double? tint,
    double? exposure,
    double? highlights,
    double? shadows,
    double? whites,
    double? blacks,
    // Color mixer properties
    double? redHue,
    double? redSaturation,
    double? redLuminance,
    double? greenHue,
    double? greenSaturation,
    double? greenLuminance,
    double? blueHue,
    double? blueSaturation,
    double? blueLuminance,
    // Tone curve properties dengan handle
    List<CurvePointData>? rgbCurvePoints,
    List<CurvePointData>? redCurvePoints,
    List<CurvePointData>? greenCurvePoints,
    List<CurvePointData>? blueCurvePoints,
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
      temperature: temperature ?? this.temperature,
      tint: tint ?? this.tint,
      exposure: exposure ?? this.exposure,
      highlights: highlights ?? this.highlights,
      shadows: shadows ?? this.shadows,
      whites: whites ?? this.whites,
      blacks: blacks ?? this.blacks,
      // Color mixer properties
      redHue: redHue ?? this.redHue,
      redSaturation: redSaturation ?? this.redSaturation,
      redLuminance: redLuminance ?? this.redLuminance,
      greenHue: greenHue ?? this.greenHue,
      greenSaturation: greenSaturation ?? this.greenSaturation,
      greenLuminance: greenLuminance ?? this.greenLuminance,
      blueHue: blueHue ?? this.blueHue,
      blueSaturation: blueSaturation ?? this.blueSaturation,
      blueLuminance: blueLuminance ?? this.blueLuminance,
      // Tone curve properties
      rgbCurvePoints:
          rgbCurvePoints ?? List<CurvePointData>.from(this.rgbCurvePoints),
      redCurvePoints:
          redCurvePoints ?? List<CurvePointData>.from(this.redCurvePoints),
      greenCurvePoints:
          greenCurvePoints ?? List<CurvePointData>.from(this.greenCurvePoints),
      blueCurvePoints:
          blueCurvePoints ?? List<CurvePointData>.from(this.blueCurvePoints),
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
      temperature: temperature,
      tint: tint,
      exposure: exposure,
      highlights: highlights,
      shadows: shadows,
      whites: whites,
      blacks: blacks,
      // Color mixer properties
      redHue: redHue,
      redSaturation: redSaturation,
      redLuminance: redLuminance,
      greenHue: greenHue,
      greenSaturation: greenSaturation,
      greenLuminance: greenLuminance,
      blueHue: blueHue,
      blueSaturation: blueSaturation,
      blueLuminance: blueLuminance,
      // Tone curve properties
      rgbCurvePoints: List<CurvePointData>.from(rgbCurvePoints),
      redCurvePoints: List<CurvePointData>.from(redCurvePoints),
      greenCurvePoints: List<CurvePointData>.from(greenCurvePoints),
      blueCurvePoints: List<CurvePointData>.from(blueCurvePoints),
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
      'temperature': temperature,
      'tint': tint,
      'exposure': exposure,
      'highlights': highlights,
      'shadows': shadows,
      'whites': whites,
      'blacks': blacks,
      // Color mixer properties
      'redHue': redHue,
      'redSaturation': redSaturation,
      'redLuminance': redLuminance,
      'greenHue': greenHue,
      'greenSaturation': greenSaturation,
      'greenLuminance': greenLuminance,
      'blueHue': blueHue,
      'blueSaturation': blueSaturation,
      'blueLuminance': blueLuminance,
      // Tone curve properties
      'rgbCurvePointsData': _encodeCurvePointsList(rgbCurvePoints),
      'redCurvePointsData': _encodeCurvePointsList(redCurvePoints),
      'greenCurvePointsData': _encodeCurvePointsList(greenCurvePoints),
      'blueCurvePointsData': _encodeCurvePointsList(blueCurvePoints),

      // Legacy tone curve points untuk kompatibilitas
      'rgbCurvePoints': _encodePointsList(rgbCurvePointsLegacy),
      'redCurvePoints': _encodePointsList(redCurvePointsLegacy),
      'greenCurvePoints': _encodePointsList(greenCurvePointsLegacy),
      'blueCurvePoints': _encodePointsList(blueCurvePointsLegacy),
    };
  }

  // Helper method to encode list of CurvePointData to JSON
  static List<Map<String, dynamic>> _encodeCurvePointsList(
    List<CurvePointData> points,
  ) {
    return points.map((point) => point.toJson()).toList();
  }

  // Helper method to encode list of Offset to JSON (legacy)
  static List<Map<String, double>> _encodePointsList(List<Offset> points) {
    return points.map((point) => {'x': point.dx, 'y': point.dy}).toList();
  }

  // Helper method to decode JSON to list of Offset (legacy)
  static List<Offset> _decodePointsList(List<dynamic> pointsData) {
    return pointsData
        .map((point) => Offset(point['x'].toDouble(), point['y'].toDouble()))
        .toList();
  }

  // Helper method to decode JSON to list of CurvePointData
  static List<CurvePointData> _decodeCurvePointsList(
    List<dynamic>? pointsData,
  ) {
    if (pointsData == null) return [];

    return pointsData
        .map(
          (point) => CurvePointData.fromJson(Map<String, dynamic>.from(point)),
        )
        .toList();
  }

  // Create model from JSON map
  factory PresetModel.fromJson(Map<String, dynamic> json) {
    // Default points for curves if not present in JSON
    final defaultPoints = [
      const CurvePointData(point: Offset(0, 256)),
      const CurvePointData(point: Offset(256, 0)),
    ];

    // Coba ambil data kurva dengan handle dahulu
    List<CurvePointData>? rgbPoints;
    List<CurvePointData>? redPoints;
    List<CurvePointData>? greenPoints;
    List<CurvePointData>? bluePoints;

    try {
      // Coba muat format baru dengan handle
      if (json['rgbCurvePointsData'] != null) {
        rgbPoints = _decodeCurvePointsList(json['rgbCurvePointsData']);
      }
      if (json['redCurvePointsData'] != null) {
        redPoints = _decodeCurvePointsList(json['redCurvePointsData']);
      }
      if (json['greenCurvePointsData'] != null) {
        greenPoints = _decodeCurvePointsList(json['greenCurvePointsData']);
      }
      if (json['blueCurvePointsData'] != null) {
        bluePoints = _decodeCurvePointsList(json['blueCurvePointsData']);
      }

      // Jika format baru tidak ada, coba muat format lama
      if (rgbPoints == null && json['rgbCurvePoints'] != null) {
        final legacyPoints = _decodePointsList(json['rgbCurvePoints']);
        rgbPoints = legacyPoints.map((p) => CurvePointData(point: p)).toList();
      }
      if (redPoints == null && json['redCurvePoints'] != null) {
        final legacyPoints = _decodePointsList(json['redCurvePoints']);
        redPoints = legacyPoints.map((p) => CurvePointData(point: p)).toList();
      }
      if (greenPoints == null && json['greenCurvePoints'] != null) {
        final legacyPoints = _decodePointsList(json['greenCurvePoints']);
        greenPoints =
            legacyPoints.map((p) => CurvePointData(point: p)).toList();
      }
      if (bluePoints == null && json['blueCurvePoints'] != null) {
        final legacyPoints = _decodePointsList(json['blueCurvePoints']);
        bluePoints = legacyPoints.map((p) => CurvePointData(point: p)).toList();
      }
    } catch (e) {
      print('Error decoding curve points: $e');
    }

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
      temperature: json['temperature']?.toDouble() ?? 0.0,
      tint: json['tint']?.toDouble() ?? 0.0,
      exposure: json['exposure']?.toDouble() ?? 0.0,
      highlights: json['highlights']?.toDouble() ?? 0.0,
      shadows: json['shadows']?.toDouble() ?? 0.0,
      whites: json['whites']?.toDouble() ?? 0.0,
      blacks: json['blacks']?.toDouble() ?? 0.0,
      // Color mixer properties
      redHue: json['redHue']?.toDouble() ?? 0.0,
      redSaturation: json['redSaturation']?.toDouble() ?? 0.0,
      redLuminance: json['redLuminance']?.toDouble() ?? 0.0,
      greenHue: json['greenHue']?.toDouble() ?? 0.0,
      greenSaturation: json['greenSaturation']?.toDouble() ?? 0.0,
      greenLuminance: json['greenLuminance']?.toDouble() ?? 0.0,
      blueHue: json['blueHue']?.toDouble() ?? 0.0,
      blueSaturation: json['blueSaturation']?.toDouble() ?? 0.0,
      blueLuminance: json['blueLuminance']?.toDouble() ?? 0.0,
      // Tone curve properties
      rgbCurvePoints: rgbPoints ?? defaultPoints,
      redCurvePoints: redPoints ?? defaultPoints,
      greenCurvePoints: greenPoints ?? defaultPoints,
      blueCurvePoints: bluePoints ?? defaultPoints,
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
        other.sampleImagePath == sampleImagePath &&
        other.temperature == temperature &&
        other.tint == tint &&
        other.exposure == exposure &&
        other.highlights == highlights &&
        other.shadows == shadows &&
        other.whites == whites &&
        other.blacks == blacks &&
        other.redHue == redHue &&
        other.redSaturation == redSaturation &&
        other.redLuminance == redLuminance &&
        other.greenHue == greenHue &&
        other.greenSaturation == greenSaturation &&
        other.greenLuminance == greenLuminance &&
        other.blueHue == blueHue &&
        other.blueSaturation == blueSaturation &&
        other.blueLuminance == blueLuminance &&
        other.rgbCurvePoints == rgbCurvePoints &&
        other.redCurvePoints == redCurvePoints &&
        other.greenCurvePoints == greenCurvePoints &&
        other.blueCurvePoints == blueCurvePoints;
  }

  // Override hashCode for value equality
  @override
  int get hashCode {
    // First group of properties
    final hash1 = Object.hash(
      id,
      name,
      brightness,
      contrast,
      saturation,
      blackAndWhite,
      borderWidth,
      borderColor.value,
      sampleImagePath,
      temperature,
    );

    // Second group of properties
    final hash2 = Object.hash(
      tint,
      exposure,
      highlights,
      shadows,
      whites,
      blacks,
      redHue,
      redSaturation,
      redLuminance,
      greenHue,
    );

    // Third group of properties
    final hash3 = Object.hash(
      greenSaturation,
      greenLuminance,
      blueHue,
      blueSaturation,
      blueLuminance,
      Object.hashAll(rgbCurvePoints),
      Object.hashAll(redCurvePoints),
      Object.hashAll(greenCurvePoints),
      Object.hashAll(blueCurvePoints),
    );

    // Combine all hash values into one
    return Object.hash(hash1, hash2, hash3);
  }
}
