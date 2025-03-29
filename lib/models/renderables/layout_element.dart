import 'dart:ui';

import 'package:photobooth/models/renderables/camera_element.dart';
import 'package:photobooth/models/renderables/image_element.dart';
import 'package:photobooth/models/renderables/text_element.dart';

abstract class LayoutElement {
  String id;
  String type;
  double x;
  double y;
  double width;
  double height;
  double rotation;
  bool isLocked;
  bool isVisible;

  LayoutElement({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotation = 0.0,
    this.isLocked = false,
    this.isVisible = true,
  });

  Map<String, dynamic> toJson();

  factory LayoutElement.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;

    switch (type) {
      case 'image':
        return ImageElement.fromJson(json);
      case 'text':
        return TextElement.fromJson(json);
      case 'camera':
        return CameraElement.fromJson(json);
      default:
        throw Exception('Unknown element type: $type');
    }
  }

  Future<void> renderExport(
    Canvas canvas,
    LayoutElement element,
    double x,
    double y,
    double elementWidth,
    double elementHeight,
    double resolutionMultiplier, {
    String imagePath,
  });
}
