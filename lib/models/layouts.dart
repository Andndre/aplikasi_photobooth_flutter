// Base class for all layout elements
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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
      case 'group':
        return GroupElement.fromJson(json);
      default:
        throw Exception('Unknown element type: $type');
    }
  }
}

class ImageElement extends LayoutElement {
  String path;
  double opacity;
  bool aspectRatioLocked; // Add this new property

  ImageElement({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required this.path,
    this.opacity = 1.0,
    this.aspectRatioLocked =
        true, // Default to true for preserving aspect ratio
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
      aspectRatioLocked:
          json['aspectRatioLocked'] as bool? ?? true, // Default to true
    );
  }
}

class TextElement extends LayoutElement {
  String text;
  String fontFamily;
  double fontSize;
  String color;
  String backgroundColor;
  bool isBold;
  bool isItalic;
  String alignment;
  bool isGoogleFont; // New property to track if this is a Google Font

  TextElement({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required this.text,
    this.fontFamily = 'Arial',
    this.fontSize = 24.0,
    this.color = '#000000',
    this.backgroundColor = 'transparent',
    this.isBold = false,
    this.isItalic = false,
    this.alignment = 'topLeft',
    this.isGoogleFont = false, // Default to false for system fonts
    super.rotation,
    super.isLocked,
    super.isVisible,
  }) : super(type: 'text');

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
      'text': text,
      'fontFamily': fontFamily,
      'fontSize': fontSize,
      'color': color,
      'backgroundColor': backgroundColor,
      'isBold': isBold,
      'isItalic': isItalic,
      'alignment': alignment,
      'isGoogleFont': isGoogleFont, // Add to JSON serialization
    };
  }

  factory TextElement.fromJson(Map<String, dynamic> json) {
    return TextElement(
      id: json['id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      isLocked: json['isLocked'] as bool? ?? false,
      isVisible: json['isVisible'] as bool? ?? true,
      text: json['text'] as String,
      fontFamily: json['fontFamily'] as String? ?? 'Arial',
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 24.0,
      color: json['color'] as String? ?? '#000000',
      backgroundColor: json['backgroundColor'] as String? ?? 'transparent',
      isBold: json['isBold'] as bool? ?? false,
      isItalic: json['isItalic'] as bool? ?? false,
      alignment: json['alignment'] as String? ?? 'topLeft',
      isGoogleFont: json['isGoogleFont'] as bool? ?? false, // Parse from JSON
    );
  }
}

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
}

class GroupElement extends LayoutElement {
  List<String> childIds; // IDs of child elements in this group
  String name;

  GroupElement({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required this.childIds,
    this.name = 'Group',
    super.rotation,
    super.isVisible,
    super.isLocked,
  }) : super(type: 'group');

  factory GroupElement.fromJson(Map<String, dynamic> json) {
    return GroupElement(
      id: json['id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      isVisible: json['isVisible'] as bool? ?? true,
      isLocked: json['isLocked'] as bool? ?? false,
      childIds: List<String>.from(json['childIds'] as List),
      name: json['name'] as String? ?? 'Group',
    );
  }

  @override
  Map<String, dynamic> toJson() {
    // Create a new map instead of using super.toJson() to avoid potential recursion
    final Map<String, dynamic> json = {
      'id': id,
      'type': type,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'rotation': rotation,
      'isVisible': isVisible,
      'isLocked': isLocked,
      // Add group-specific properties
      'childIds': childIds,
      'name': name,
    };

    return json;
  }
}

class Layouts {
  String name;
  int id;
  int width;
  int height;
  List<LayoutElement> elements;
  String backgroundColor;

  Layouts({
    required this.name,
    required this.id,
    required this.width,
    required this.height,
    List<LayoutElement>? elements,
    this.backgroundColor = '#FFFFFF',
  }) : elements = elements ?? [];

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'id': id,
      'width': width,
      'height': height,
      'elements': elements.map((e) => e.toJson()).toList(),
      'backgroundColor': backgroundColor,
    };
  }

  factory Layouts.fromJson(Map<String, dynamic> json) {
    List<LayoutElement> elementsList = [];
    if (json['elements'] != null) {
      final elements = json['elements'] as List;
      elementsList =
          elements.map((elemJson) => LayoutElement.fromJson(elemJson)).toList();
    } else if (json['coordinates'] != null && json['basePhoto'] != null) {
      // Convert old format to new format
      final coordinates = json['coordinates'] as List;
      if (json['basePhoto'].isNotEmpty) {
        elementsList.add(
          ImageElement(
            id: 'background',
            x: 0,
            y: 0,
            width: json['width'].toDouble(),
            height: json['height'].toDouble(),
            path: json['basePhoto'],
          ),
        );
      }
      for (int i = 0; i < coordinates.length; i++) {
        final coord = coordinates[i];
        elementsList.add(
          CameraElement(
            id: 'camera_${i + 1}',
            x: coord[0].toDouble(),
            y: coord[1].toDouble(),
            width: coord[2].toDouble(),
            height: coord[3].toDouble(),
            label: 'Photo Spot ${i + 1}',
          ),
        );
      }
    }

    return Layouts(
      name: json['name'],
      id: json['id'],
      width: json['width'],
      height: json['height'],
      elements: elementsList,
      backgroundColor: json['backgroundColor'] ?? '#FFFFFF',
    );
  }

  // New method to export layout with specified photos
  Future<File?> exportAsImage({
    required String exportPath,
    required List<String> photoFilePaths,
    double resolutionMultiplier = 1.0,
    bool includeBackground = true,
  }) async {
    try {
      // Create a recorder
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Calculate dimensions
      final width = (this.width * resolutionMultiplier).toDouble();
      final height = (this.height * resolutionMultiplier).toDouble();

      // Draw background if needed
      if (includeBackground) {
        final bgColor = _hexToColor(backgroundColor);
        canvas.drawRect(
          Rect.fromLTWH(0, 0, width, height),
          Paint()..color = bgColor,
        );
      }

      // Find all camera slots in the layout
      final cameraElements =
          elements
              .where((e) => e.type == 'camera' && e.isVisible)
              .cast<CameraElement>()
              .toList();

      // Map photos to camera slots
      Map<String, ui.Image> cameraImages = {};

      // Preload all photos
      int photoIndex = 0;
      for (final cameraElement in cameraElements) {
        // Check if we have enough photos
        if (photoIndex < photoFilePaths.length) {
          final file = File(photoFilePaths[photoIndex]);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final codec = await ui.instantiateImageCodec(bytes);
            final frame = await codec.getNextFrame();
            cameraImages[cameraElement.id] = frame.image;
            photoIndex++;
          }
        }
      }

      // Sort elements by their order in the layout - render bottom to top
      final sortedElements = [...elements];

      // Draw each element
      for (final element in sortedElements) {
        // Skip invisible elements
        if (!element.isVisible) continue;

        // Skip group elements - render their children individually
        if (element.type == 'group') continue;

        // Scale the element's position and size
        final x = element.x * resolutionMultiplier;
        final y = element.y * resolutionMultiplier;
        final elementWidth = element.width * resolutionMultiplier;
        final elementHeight = element.height * resolutionMultiplier;

        // Save the current canvas state before applying transformations
        canvas.save();

        // Apply rotation if needed
        if (element.rotation != 0) {
          // Calculate center of the element for rotation
          final centerX = x + (elementWidth / 2);
          final centerY = y + (elementHeight / 2);

          // Translate to center, rotate, then translate back
          canvas.translate(centerX, centerY);
          canvas.rotate((element.rotation * pi) / 180);
          canvas.translate(-centerX, -centerY);
        }

        // Render based on element type
        switch (element.type) {
          case 'image':
            await _renderImageElement(
              canvas,
              element as ImageElement,
              x,
              y,
              elementWidth,
              elementHeight,
            );
            break;

          case 'text':
            _renderTextElement(
              canvas,
              element as TextElement,
              x,
              y,
              elementWidth,
              elementHeight,
              resolutionMultiplier,
            );
            break;

          case 'camera':
            final cameraElement = element as CameraElement;
            final image = cameraImages[cameraElement.id];
            if (image != null) {
              _renderCameraWithImage(
                canvas,
                cameraElement,
                image,
                x,
                y,
                elementWidth,
                elementHeight,
              );
            } else {
              _renderCameraPlaceholder(
                canvas,
                cameraElement,
                x,
                y,
                elementWidth,
                elementHeight,
              );
            }
            break;
        }

        // Restore the canvas state after rendering this element
        canvas.restore();
      }

      // End recording and convert to image
      final picture = recorder.endRecording();
      final img = await picture.toImage(width.round(), height.round());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        return null;
      }

      // Create file and write image data
      final file = File(exportPath);
      await file.writeAsBytes(byteData.buffer.asUint8List());

      return file;
    } catch (e) {
      print('Error exporting layout: $e');
      return null;
    }
  }

  // Helper to render an image element
  static Future<void> _renderImageElement(
    Canvas canvas,
    ImageElement element,
    double x,
    double y,
    double width,
    double height,
  ) async {
    try {
      final file = File(element.path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final image = frame.image;

        // Draw with opacity
        final paint =
            Paint()
              ..filterQuality = FilterQuality.high
              ..isAntiAlias = true
              ..color = Colors.white.withOpacity(element.opacity);

        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          Rect.fromLTWH(x, y, width, height),
          paint,
        );
      }
    } catch (e) {
      print('Error rendering image element: $e');
    }
  }

  // Helper to render a text element
  static void _renderTextElement(
    Canvas canvas,
    TextElement element,
    double x,
    double y,
    double width,
    double height,
    double resolutionMultiplier,
  ) {
    try {
      // Create a rect for the background if needed
      final rect = Rect.fromLTWH(x, y, width, height);

      // Draw background if not transparent
      if (element.backgroundColor != 'transparent') {
        final bgPaint = Paint()..color = _hexToColor(element.backgroundColor);
        canvas.drawRect(rect, bgPaint);
      }

      // Create text style
      final textStyle = TextStyle(
        color: _hexToColor(element.color),
        fontSize: element.fontSize * resolutionMultiplier,
        fontWeight: element.isBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: element.isItalic ? FontStyle.italic : FontStyle.normal,
        fontFamily: element.fontFamily,
      );

      // Create paragraph style based on alignment
      final paragraphStyle = ui.ParagraphStyle(
        textAlign: _getTextAlign(element.alignment),
        textDirection: TextDirection.ltr,
      );

      // Build paragraph
      final paragraphBuilder =
          ui.ParagraphBuilder(paragraphStyle)
            ..pushStyle(textStyle as ui.TextStyle)
            ..addText(element.text);

      final paragraph = paragraphBuilder.build();
      paragraph.layout(ui.ParagraphConstraints(width: width));

      // Position paragraph according to vertical alignment
      double dy = y;
      if (element.alignment.contains('center')) {
        dy = y + (height - paragraph.height) / 2;
      } else if (element.alignment.contains('bottom')) {
        dy = y + height - paragraph.height;
      }

      // Draw text
      canvas.drawParagraph(paragraph, Offset(x, dy));
    } catch (e) {
      print('Error rendering text element: $e');
    }
  }

  // Helper to render a camera with an actual image
  static void _renderCameraWithImage(
    Canvas canvas,
    CameraElement element,
    ui.Image image,
    double x,
    double y,
    double width,
    double height,
  ) {
    try {
      final paint =
          Paint()
            ..filterQuality = FilterQuality.high
            ..isAntiAlias = true;

      // Draw the image
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(x, y, width, height),
        paint,
      );

      // Optionally draw a border
      final borderPaint =
          Paint()
            ..color = Colors.white.withOpacity(0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0;

      canvas.drawRect(Rect.fromLTWH(x, y, width, height), borderPaint);
    } catch (e) {
      print('Error rendering camera with image: $e');
      _renderCameraPlaceholder(canvas, element, x, y, width, height);
    }
  }

  // Helper to render a placeholder for camera elements
  static void _renderCameraPlaceholder(
    Canvas canvas,
    CameraElement element,
    double x,
    double y,
    double width,
    double height,
  ) {
    // Blue rect with camera icon
    final bgPaint = Paint()..color = Colors.blue.withOpacity(0.2);
    final borderPaint =
        Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

    canvas.drawRect(Rect.fromLTWH(x, y, width, height), bgPaint);
    canvas.drawRect(Rect.fromLTWH(x, y, width, height), borderPaint);

    // Draw camera icon
    final iconPainter = TextPainter(
      text: const TextSpan(text: '📷', style: TextStyle(fontSize: 24)),
      textDirection: TextDirection.ltr,
    );
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      Offset(
        x + (width - iconPainter.width) / 2,
        y + (height - iconPainter.height) / 2,
      ),
    );

    // Add label
    final textPainter = TextPainter(
      text: TextSpan(
        text: element.label,
        style: const TextStyle(color: Colors.blue, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(x + 5, y + height - textPainter.height - 5),
    );
  }

  // Helper to convert text alignment string to TextAlign
  static TextAlign _getTextAlign(String alignment) {
    if (alignment.contains('Left')) {
      return TextAlign.left;
    } else if (alignment.contains('Right')) {
      return TextAlign.right;
    } else {
      return TextAlign.center;
    }
  }

  // Helper to convert hex color to Color
  static Color _hexToColor(String hexColor) {
    if (hexColor == 'transparent') return Colors.transparent;

    hexColor = hexColor.replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    return Color(int.parse(hexColor, radix: 16));
  }
}
