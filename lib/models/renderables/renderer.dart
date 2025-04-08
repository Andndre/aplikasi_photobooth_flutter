import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:photobooth/models/layout_model.dart';
import 'dart:ui' as ui;

import 'package:photobooth/models/renderables/fonts.dart';

class Renderer {
  static Future<File?> exportLayoutWithImages({
    required LayoutModel layout,
    required String exportPath,
    required List<String> filePaths,
    double resolutionMultiplier = 1.0,
  }) async {
    if (layout.allCameraElements.length != filePaths.length) {
      throw Exception(
        "Camera spots count doesn't match the number of provided images.",
      );
    }

    try {
      await Fonts.loadUsedFonts(layout: layout);

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      final width = (layout.width * resolutionMultiplier).toDouble();
      final height = (layout.height * resolutionMultiplier).toDouble();

      final bgColor = ColorsHelper.hexToColor(layout.backgroundColor);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, width, height),
        Paint()..color = bgColor,
      );

      final elements = layout.elements;
      int index = 0;

      for (final element in elements) {
        if (!element.isVisible) continue;

        final x = element.x * resolutionMultiplier;
        final y = element.y * resolutionMultiplier;
        final elementWidth = element.width * resolutionMultiplier;
        final elementHeight = element.height * resolutionMultiplier;

        canvas.save();

        if (element.rotation != 0) {
          // Calculate center of the element for rotation
          final centerX = x + (elementWidth / 2);
          final centerY = y + (elementHeight / 2);

          // Translate to center, rotate, then translate back
          canvas.translate(centerX, centerY);
          canvas.rotate((element.rotation * pi) / 180);
          canvas.translate(-centerX, -centerY);
        }

        try {
          switch (element.type) {
            case 'camera':
              await element.renderExport(
                canvas,
                element,
                x,
                y,
                elementWidth,
                elementHeight,
                resolutionMultiplier,
                imagePath: filePaths[index++],
              );
              break;
            case 'image':
            case 'text':
              await element.renderExport(
                canvas,
                element,
                x,
                y,
                elementWidth,
                elementHeight,
                resolutionMultiplier,
              );
              break;
          }
        } catch (e) {
          print('Error rendering element ${element.id}: $e');
        }

        canvas.restore();
      }

      final picture = recorder.endRecording();
      final img = await picture.toImage(width.round(), height.round());

      try {
        final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

        if (byteData == null) {
          return null;
        }

        final file = File(exportPath);
        await file.writeAsBytes(byteData.buffer.asUint8List());

        return file;
      } finally {
        // Ensure image is disposed
        img.dispose();
      }
    } catch (e) {
      print('Error in exportLayoutWithImages: $e');
      return null;
    }
  }
}

class ColorsHelper {
  static ui.Color hexToColor(String hexColor) {
    if (hexColor == 'transparent') return Colors.transparent;

    hexColor = hexColor.replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    return ui.Color(int.parse(hexColor, radix: 16));
  }
}
