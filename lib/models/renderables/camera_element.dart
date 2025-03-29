import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:photobooth/models/renderables/layout_element.dart';

class CameraElement extends LayoutElement {
  String label;

  CameraElement({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    this.label = 'Photo Spot',
    super.rotation,
    super.isLocked,
    super.isVisible,
  }) : super(type: 'camera');

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'rotation': rotation,
      'isLocked': isLocked,
      'isVisible': isVisible,
      'label': label,
    };
  }

  factory CameraElement.fromJson(Map<String, dynamic> json) {
    return CameraElement(
      id: json['id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      isLocked: json['isLocked'] as bool? ?? false,
      isVisible: json['isVisible'] as bool? ?? true,
      label: json['label'] as String? ?? 'Photo Spot',
    );
  }

  @override
  void renderExport(
    Canvas canvas,
    LayoutElement e,
    double x,
    double y,
    double elementWidth,
    double elementHeight,
    double resolutionMultiplier, {
    String? imagePath,
  }) async {
    try {
      if (imagePath == null) {
        throw Exception("TODO: handle this error when image path is null");
      }
      final file = File(imagePath);
      if (await file.exists()) {
        throw Exception("TODO: handle this error when image is not found");
      }
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      ui.Image image = frame.image;
      // Draw the sample photo inside the camera slot
      final paint =
          Paint()
            ..filterQuality = FilterQuality.high
            ..isAntiAlias = true;

      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(
          x,
          y,
          width * resolutionMultiplier,
          height * resolutionMultiplier,
        ),
        paint,
      );
    } catch (e) {
      print('Error rendering camera element: $e');
    }
  }
}
