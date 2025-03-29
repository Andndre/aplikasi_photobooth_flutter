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
    required double resolutionMultiplier,
    required List<String> filePaths,
  }) async {
    if (layout.allCameraElements.length != filePaths.length) {
      throw Exception(
        "TODO: handle this error when the camera count is not the same as file paths length",
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

        print("Rendering ${element.type}");
        switch (element.type) {
          case 'camera':
            element.renderExport(
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
            element.renderExport(
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

        canvas.restore();
      }

      final picture = recorder.endRecording();
      final img = await picture.toImage(width.round(), height.round());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        return null;
      }

      final file = File(exportPath);
      await file.writeAsBytes(byteData.buffer.asUint8List());

      return file;
    } catch (e) {
      print('Error rendering text element: $e');
    }
    return null;
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
