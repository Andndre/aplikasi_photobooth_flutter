import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photobooth/models/renderables/layout_element.dart';
import 'package:photobooth/models/renderables/renderer.dart';

class TextElement extends LayoutElement {
  String text;
  String fontFamily;
  double fontSize;
  String color;
  String backgroundColor;
  bool isBold;
  bool isItalic;
  String alignment;
  bool isGoogleFont;

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
    this.isGoogleFont = false,
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
      'isGoogleFont': isGoogleFont,
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
      isGoogleFont: json['isGoogleFont'] as bool? ?? false,
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
    TextElement element = e as TextElement;
    try {
      // Create a rect for the background if needed
      final rect = Rect.fromLTWH(
        x,
        y,
        width * resolutionMultiplier,
        height * resolutionMultiplier,
      );

      // Draw background if not transparent
      if (element.backgroundColor != 'transparent') {
        final bgPaint =
            Paint()..color = ColorsHelper.hexToColor(element.backgroundColor);
        canvas.drawRect(rect, bgPaint);
      }

      // final testPaint =
      //     Paint()
      //       ..color = Colors.green
      //       ..style = PaintingStyle.stroke;
      // // draw outline for debugging
      // canvas.drawRect(rect, testPaint);

      // Create text style with correct properties
      TextStyle textStyle;

      // Special handling for Google Fonts
      if (element.isGoogleFont) {
        try {
          textStyle = GoogleFonts.getFont(
            element.fontFamily,
            color: ColorsHelper.hexToColor(element.color),
            fontSize: element.fontSize * resolutionMultiplier,
            fontWeight: element.isBold ? FontWeight.bold : FontWeight.normal,
            fontStyle: element.isItalic ? FontStyle.italic : FontStyle.normal,
          );
        } catch (e) {
          print(
            'Error loading Google Font: ${element.fontFamily}. Using fallback font.',
          );
          // Fallback to system font if Google Font fails
          textStyle = TextStyle(
            fontFamily: 'Arial',
            color: ColorsHelper.hexToColor(element.color),
            fontSize: element.fontSize * resolutionMultiplier,
            fontWeight: element.isBold ? FontWeight.bold : FontWeight.normal,
            fontStyle: element.isItalic ? FontStyle.italic : FontStyle.normal,
          );
        }
      } else {
        // System font
        textStyle = TextStyle(
          fontFamily: element.fontFamily,
          color: ColorsHelper.hexToColor(element.color),
          fontSize: element.fontSize * resolutionMultiplier,
          fontWeight: element.isBold ? FontWeight.bold : FontWeight.normal,
          fontStyle: element.isItalic ? FontStyle.italic : FontStyle.normal,
        );
      }

      // Create a TextPainter to handle precise text rendering
      final textPainter = TextPainter(
        text: TextSpan(text: element.text, style: textStyle),
        textAlign: _getTextAlign(element.alignment),
        textDirection: TextDirection.ltr,
      );

      // Layout the text within the constraints
      textPainter.layout(maxWidth: width * resolutionMultiplier);

      // Calculate correct position based on alignment
      double dx = x;
      double dy = y;

      // Horizontal alignment - make consistent with _getTextAlignment logic
      final lowerAlignment = element.alignment.toLowerCase();

      if (!lowerAlignment.contains('left') &&
          !lowerAlignment.contains('right')) {
        if (lowerAlignment.contains('center')) {
          // Center horizontally
          dx = x + (width - textPainter.width) / 2;
        }
      } else if (lowerAlignment.contains('right')) {
        // Align to right
        dx = x + width - textPainter.width;
      }
      // Else align to left (default)

      // Vertical alignment
      if (!lowerAlignment.contains('top') &&
          !lowerAlignment.contains('bottom')) {
        if (lowerAlignment.contains('center')) {
          // Center vertically
          dy = y + (height * resolutionMultiplier - textPainter.height) / 2;
        }
      } else if (lowerAlignment.contains('bottom')) {
        // Align to bottom
        dy = y + height * resolutionMultiplier - textPainter.height;
      }
      // Else align to top (default)

      // Draw the text at the calculated position
      textPainter.paint(canvas, Offset(dx, dy));
    } catch (e) {
      print('Error rendering text element: $e');
    }
  }

  TextAlign _getTextAlign(String alignment) {
    // Make case-insensitive
    final lowerAlignment = alignment.toLowerCase();

    if (lowerAlignment.contains('left')) {
      return TextAlign.left;
    } else if (lowerAlignment.contains('right')) {
      return TextAlign.right;
    } else if (lowerAlignment.contains('center')) {
      return TextAlign.center;
    } else {
      // Default alignment
      return TextAlign.left;
    }
  }
}
