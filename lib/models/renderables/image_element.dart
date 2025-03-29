import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:photobooth/models/renderables/layout_element.dart';

class ImageElement extends LayoutElement {
  String path;
  double opacity;
  bool aspectRatioLocked;

  ImageElement({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required this.path,
    this.opacity = 1.0,
    this.aspectRatioLocked = true,
    super.rotation,
    super.isLocked,
    super.isVisible,
  }) : super(type: 'image');

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
      'path': path,
      'opacity': opacity,
      'aspectRatioLocked': aspectRatioLocked,
    };
  }

  factory ImageElement.fromJson(Map<String, dynamic> json) {
    return ImageElement(
      id: json['id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      isLocked: json['isLocked'] as bool? ?? false,
      isVisible: json['isVisible'] as bool? ?? true,
      path: json['path'] as String,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      aspectRatioLocked: json['aspectRatioLocked'] as bool? ?? true,
    );
  }

  @override
  Future<void> renderExport(
    Canvas canvas,
    LayoutElement element,
    double x,
    double y,
    double elementWidth,
    double elementHeight,
    double resolutionMultiplier, {
    String? imagePath,
  }) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        // Use a simpler approach with fewer resource management concerns
        final bytes = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);

        try {
          final frame = await codec.getNextFrame();
          final image = frame.image;

          // Draw with opacity
          final paint =
              Paint()
                ..filterQuality = FilterQuality.high
                ..isAntiAlias = true
                ..color = Colors.white.withOpacity(opacity);

          canvas.drawImageRect(
            image,
            Rect.fromLTWH(
              0,
              0,
              image.width.toDouble(),
              image.height.toDouble(),
            ),
            Rect.fromLTWH(
              x,
              y,
              width * resolutionMultiplier,
              height * resolutionMultiplier,
            ),
            paint,
          );
        } finally {
          // Dispose the codec when done
          codec.dispose();
        }
      } else {
        throw Exception("Image not found: $path");
      }
    } catch (e) {
      print('Error rendering image element: $e');
      // Draw a placeholder for failed images
      _renderImagePlaceholder(
        canvas,
        x,
        y,
        width * resolutionMultiplier,
        height * resolutionMultiplier,
      );
    }
  }

  // Add a method to render a placeholder when image loading fails
  void _renderImagePlaceholder(
    Canvas canvas,
    double x,
    double y,
    double width,
    double height,
  ) {
    // Grey rectangle with error icon visual
    final bgPaint = Paint()..color = Colors.grey.withOpacity(0.3);
    final borderPaint =
        Paint()
          ..color = Colors.grey
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

    canvas.drawRect(Rect.fromLTWH(x, y, width, height), bgPaint);
    canvas.drawRect(Rect.fromLTWH(x, y, width, height), borderPaint);

    // Draw X pattern to indicate missing image
    final linePaint =
        Paint()
          ..color = Colors.grey
          ..strokeWidth = 2.0;

    canvas.drawLine(Offset(x, y), Offset(x + width, y + height), linePaint);
    canvas.drawLine(Offset(x + width, y), Offset(x, y + height), linePaint);
  }
}
