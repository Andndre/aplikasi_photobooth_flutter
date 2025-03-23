// Base class for all layout elements
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';

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
      // Create screenshot controller
      final screenshotController = ScreenshotController();

      // Build the layout widget
      final layoutWidget = buildLayoutPreviewWidget(
        photoFilePaths: photoFilePaths,
        includeBackground: includeBackground,
      );

      // Calculate dimensions with multiplier
      final exportWidth = (width * resolutionMultiplier).toInt();
      final exportHeight = (height * resolutionMultiplier).toInt();

      // Capture the widget as a Uint8List
      final Uint8List imageBytes = await screenshotController.captureFromWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Material(
            color: Colors.transparent,
            child: Transform.scale(
              scale: resolutionMultiplier,
              child: layoutWidget,
            ),
          ),
        ),
        pixelRatio: 1.0, // We're already scaling the widget
        context: null,
        delay: const Duration(milliseconds: 100),
        targetSize: Size(exportWidth.toDouble(), exportHeight.toDouble()),
      );

      // Write the image to a file
      final file = File(exportPath);
      await file.writeAsBytes(imageBytes);

      return file;
    } catch (e) {
      print('Error exporting layout: $e');
      // Fallback to the original method if the widget method fails
      return _exportAsImageFallback(
        exportPath: exportPath,
        photoFilePaths: photoFilePaths,
        resolutionMultiplier: resolutionMultiplier,
        includeBackground: includeBackground,
      );
    }
  }

  // Fallback method using the original canvas approach
  Future<File?> _exportAsImageFallback({
    required String exportPath,
    required List<String> photoFilePaths,
    double resolutionMultiplier = 1.0,
    bool includeBackground = true,
  }) async {
    // Original canvas-based method as a fallback
    // ...existing canvas rendering code from the previous implementation...
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
      print('Error in fallback export: $e');
      return null;
    }
  }

  // New method to create a widget representing the layout for export
  Widget buildLayoutPreviewWidget({
    required List<String> photoFilePaths,
    bool includeBackground = true,
  }) {
    // Create a map of camera elements to photo paths
    final cameraElements =
        elements
            .where((e) => e.type == 'camera' && e.isVisible)
            .cast<CameraElement>()
            .toList();

    Map<String, String> cameraPhotos = {};
    for (
      int i = 0;
      i < cameraElements.length && i < photoFilePaths.length;
      i++
    ) {
      cameraPhotos[cameraElements[i].id] = photoFilePaths[i];
    }

    return Container(
      width: width.toDouble(),
      height: height.toDouble(),
      color:
          includeBackground ? _hexToColor(backgroundColor) : Colors.transparent,
      child: Stack(
        children:
            elements.where((e) => e.isVisible).map((element) {
              // Skip group elements as we'll render their children individually
              if (element.type == 'group') return const SizedBox.shrink();

              return Positioned(
                left: element.x,
                top: element.y,
                width: element.width,
                height: element.height,
                child: Transform.rotate(
                  angle: element.rotation * (pi / 180),
                  child: _buildElementWidget(element, cameraPhotos),
                ),
              );
            }).toList(),
      ),
    );
  }

  // Helper method to build appropriate widget for each element type
  Widget _buildElementWidget(
    LayoutElement element,
    Map<String, String> cameraPhotos,
  ) {
    switch (element.type) {
      case 'image':
        return _buildImageWidget(element as ImageElement);
      case 'text':
        return _buildTextWidget(element as TextElement);
      case 'camera':
        final cameraElement = element as CameraElement;
        final photoPath = cameraPhotos[cameraElement.id];
        return photoPath != null && photoPath.isNotEmpty
            ? _buildCameraWithImageWidget(cameraElement, photoPath)
            : _buildCameraPlaceholderWidget(cameraElement);
      default:
        return const SizedBox.shrink();
    }
  }

  // Widget for image elements
  Widget _buildImageWidget(ImageElement element) {
    try {
      final file = File(element.path);
      if (file.existsSync()) {
        return Opacity(
          opacity: element.opacity,
          child: Image.file(file, fit: BoxFit.fill),
        );
      }
    } catch (e) {
      print('Error loading image: $e');
    }
    // Fallback if image can't be loaded
    return Container(
      color: Colors.grey.withOpacity(0.3),
      child: const Center(
        child: Icon(Icons.image_not_supported, color: Colors.grey),
      ),
    );
  }

  // Widget for text elements
  Widget _buildTextWidget(TextElement element) {
    return Container(
      width: element.width,
      height: element.height,
      color:
          element.backgroundColor != 'transparent'
              ? _hexToColor(element.backgroundColor)
              : Colors.transparent,
      alignment: _getTextAlignment(element.alignment),
      child: Text(
        element.text,
        style: TextStyle(
          color: _hexToColor(element.color),
          fontSize: element.fontSize,
          fontWeight: element.isBold ? FontWeight.bold : FontWeight.normal,
          fontStyle: element.isItalic ? FontStyle.italic : FontStyle.normal,
          fontFamily: element.fontFamily,
        ),
        textAlign: _getTextAlign(element.alignment),
      ),
    );
  }

  // Widget for camera elements with an image
  Widget _buildCameraWithImageWidget(CameraElement element, String imagePath) {
    try {
      final file = File(imagePath);
      if (file.existsSync()) {
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
          ),
          child: Image.file(file, fit: BoxFit.cover),
        );
      }
    } catch (e) {
      print('Error loading camera image: $e');
    }
    // Fallback to placeholder if image can't be loaded
    return _buildCameraPlaceholderWidget(element);
  }

  // Widget for camera placeholders
  Widget _buildCameraPlaceholderWidget(CameraElement element) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.2),
        border: Border.all(color: Colors.blue, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.camera_alt, size: 48, color: Colors.blue),
          const SizedBox(height: 8),
          Text(
            element.label,
            style: const TextStyle(color: Colors.blue),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper for getting text alignment for Container
  Alignment _getTextAlignment(String alignment) {
    if (alignment.contains('top')) {
      if (alignment.contains('Left')) return Alignment.topLeft;
      if (alignment.contains('Right')) return Alignment.topRight;
      return Alignment.topCenter;
    } else if (alignment.contains('bottom')) {
      if (alignment.contains('Left')) return Alignment.bottomLeft;
      if (alignment.contains('Right')) return Alignment.bottomRight;
      return Alignment.bottomCenter;
    } else {
      if (alignment.contains('Left')) return Alignment.centerLeft;
      if (alignment.contains('Right')) return Alignment.centerRight;
      return Alignment.center;
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

  // Helper to render a text element - improved implementation
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

      // Create text style with correct color
      final color = _hexToColor(element.color);

      // Create a TextPainter to properly handle text rendering
      final textPainter = TextPainter(
        text: TextSpan(
          text: element.text,
          style: TextStyle(
            color: color,
            fontSize: element.fontSize * resolutionMultiplier,
            fontWeight: element.isBold ? FontWeight.bold : FontWeight.normal,
            fontStyle: element.isItalic ? FontStyle.italic : FontStyle.normal,
            fontFamily: element.fontFamily,
            // The package will handle Google Fonts when rendering
          ),
        ),
        textAlign: _getTextAlign(element.alignment),
        textDirection: TextDirection.ltr,
      );

      // Layout the text within the constraints
      textPainter.layout(maxWidth: width);

      // Position the text based on the alignment
      double dx = x;
      double dy = y;

      // Handle horizontal alignment
      if (element.alignment.contains('center') &&
          !element.alignment.contains('Left') &&
          !element.alignment.contains('Right')) {
        dx = x + (width - textPainter.width) / 2;
      } else if (element.alignment.contains('Right')) {
        dx = x + width - textPainter.width;
      }

      // Handle vertical alignment
      if (element.alignment.contains('center')) {
        dy = y + (height - textPainter.height) / 2;
      } else if (element.alignment.contains('bottom')) {
        dy = y + height - textPainter.height;
      }

      // Draw the text
      textPainter.paint(canvas, Offset(dx, dy));
    } catch (e) {
      print('Error rendering text element: $e');

      // Fallback rendering method if the above fails
      _renderTextElementFallback(
        canvas,
        element,
        x,
        y,
        width,
        height,
        resolutionMultiplier,
      );
    }
  }

  // Fallback method for text rendering using basic paragraph builder
  static void _renderTextElementFallback(
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

      // Create basic paragraph style based on alignment
      final paragraphStyle = ui.ParagraphStyle(
        textAlign: _getTextAlign(element.alignment),
        textDirection: TextDirection.ltr,
      );

      // Create text style
      final textStyle = ui.TextStyle(
        color: _hexToColor(element.color),
        fontSize: element.fontSize * resolutionMultiplier,
        fontWeight: element.isBold ? ui.FontWeight.bold : ui.FontWeight.normal,
        fontStyle: element.isItalic ? ui.FontStyle.italic : ui.FontStyle.normal,
        fontFamily: element.fontFamily,
      );

      // Build paragraph
      final paragraphBuilder =
          ui.ParagraphBuilder(paragraphStyle)
            ..pushStyle(textStyle)
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
      print('Error in fallback text rendering: $e');

      // Last resort - draw a simple rectangle with basic text
      final paint = Paint()..color = _hexToColor(element.color);
      final textPaint =
          Paint()
            ..color = _hexToColor(element.color)
            ..style = PaintingStyle.fill;

      canvas.drawRect(
        Rect.fromLTWH(x, y, width, height),
        Paint()..color = _hexToColor(element.backgroundColor),
      );

      // Draw a simple text representation
      canvas.drawCircle(Offset(x + width / 2, y + height / 2), 10, paint);
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
