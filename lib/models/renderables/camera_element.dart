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
  Future<void> renderExport(
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
        print("Error: No image path provided for camera element");
        _renderCameraPlaceholder(canvas, x, y, elementWidth, elementHeight);
        return;
      }

      final file = File(imagePath);
      if (!(await file.exists())) {
        print("Error: Image file not found at path: $imagePath");
        _renderCameraPlaceholder(canvas, x, y, elementWidth, elementHeight);
        return;
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
      _renderCameraPlaceholder(canvas, x, y, elementWidth, elementHeight);
    }
  }

  // Add helper method to render a placeholder when an image is not available
  void _renderCameraPlaceholder(
    Canvas canvas,
    double x,
    double y,
    double width,
    double height,
  ) {
    // Blue rect with camera icon placeholder
    final bgPaint = Paint()..color = Colors.blue.withOpacity(0.2);
    final borderPaint =
        Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

    canvas.drawRect(Rect.fromLTWH(x, y, width, height), bgPaint);
    canvas.drawRect(Rect.fromLTWH(x, y, width, height), borderPaint);

    // Draw label
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: Colors.blue, fontSize: 16),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: width - 10);
    textPainter.paint(
      canvas,
      Offset(x + 5, y + height - textPainter.height - 5),
    );
  }
}
