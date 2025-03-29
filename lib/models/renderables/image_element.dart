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
  void renderExport(
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
        final bytes = await file.readAsBytes();
        final descriptor = await ui.ImageDescriptor.encoded(
          await ui.ImmutableBuffer.fromUint8List(bytes),
        );
        final codec = await descriptor.instantiateCodec();
        final frame = await codec.getNextFrame();
        final image = frame.image;

        descriptor.dispose();
        codec.dispose();

        // Draw with opacity
        final paint =
            Paint()
              ..filterQuality = FilterQuality.high
              ..isAntiAlias = true
              ..color = Colors.white.withValues(alpha: opacity);

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
      } else {
        throw Exception("Imgae not found: $path");
      }
    } catch (e) {
      print('Error rendering image element: $e');
    }
  }
}
