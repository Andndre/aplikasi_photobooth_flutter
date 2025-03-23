import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import '../../models/layouts.dart';
import 'package:provider/provider.dart';
import '../../providers/layout_editor.dart';
import 'package:google_fonts/google_fonts.dart';

class ElementWidget extends StatelessWidget {
  final LayoutElement element;
  final bool isGroupChild;
  // Add GoogleFonts list for checking
  final List<String> googleFontsList = GoogleFonts.asMap().keys.toList();

  ElementWidget({super.key, required this.element, this.isGroupChild = false});

  @override
  Widget build(BuildContext context) {
    // Get the editor provider to check if this element is selected
    final editorProvider = Provider.of<LayoutEditorProvider>(context);
    final isSelected = editorProvider.isElementSelected(element.id);

    // Ensure width and height are at least 10 pixels
    final safeWidth = max(10.0, element.width);
    final safeHeight = max(10.0, element.height);

    return Transform.rotate(
      angle: element.rotation * (pi / 180),
      child: SizedBox(
        width: safeWidth,
        height: safeHeight,
        child: _buildElementContent(context, isSelected),
      ),
    );
  }

  Future<String?> _loadFontFamily(String fontName) async {
    try {
      final fontFile = File('C:\\Windows\\Fonts\\$fontName.ttf');
      if (await fontFile.exists()) {
        final fontLoader = FontLoader(fontName);
        final bytes = await fontFile.readAsBytes();
        fontLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
        await fontLoader.load();
        return fontName;
      }
      return null;
    } catch (e) {
      print('Error loading font $fontName: $e');
      return null;
    }
  }

  Widget _buildElementContent(BuildContext context, bool isSelected) {
    // For group elements, we'll handle rendering differently since
    // the canvas will now handle the group rendering and interactions
    if (element.type == 'group' && !isGroupChild) {
      // Return a simple container since the actual group rendering is handled in the canvas
      return Container(decoration: BoxDecoration(color: Colors.transparent));
    }

    switch (element.type) {
      case 'image':
        final imageElement = element as ImageElement;
        final file = File(imageElement.path);
        return file.existsSync()
            ? Opacity(
              opacity: imageElement.opacity,
              child: Image.file(
                file,
                fit:
                    imageElement.aspectRatioLocked
                        ? BoxFit.contain
                        : BoxFit.fill,
                width: element.width,
                height: element.height,
              ),
            )
            : Container(
              color: Colors.grey[300],
              child: const Center(
                child: Icon(Icons.image_not_supported, size: 24),
              ),
            );

      case 'text':
        final textElement = element as TextElement;

        // Create the text style based on font source
        TextStyle textStyle;
        if (googleFontsList.contains(textElement.fontFamily)) {
          try {
            // Use Google Fonts with the specified fontFamily
            textStyle = GoogleFonts.getFont(
              textElement.fontFamily,
              color: _hexToColor(textElement.color),
              fontSize: max(8.0, textElement.fontSize).toDouble(),
              fontWeight:
                  textElement.isBold ? FontWeight.bold : FontWeight.normal,
              fontStyle:
                  textElement.isItalic ? FontStyle.italic : FontStyle.normal,
            );
          } catch (e) {
            print(
              'Error loading Google Font: ${textElement.fontFamily}. Using system font instead.',
            );
            textStyle = TextStyle(
              fontFamily: textElement.fontFamily,
              color: _hexToColor(textElement.color),
              fontSize: max(8.0, textElement.fontSize).toDouble(),
              fontWeight:
                  textElement.isBold ? FontWeight.bold : FontWeight.normal,
              fontStyle:
                  textElement.isItalic ? FontStyle.italic : FontStyle.normal,
              decoration: TextDecoration.none,
            );
          }
        } else {
          // Use system font directly
          textStyle = TextStyle(
            fontFamily:
                textElement.fontFamily.isEmpty
                    ? 'Arial'
                    : textElement.fontFamily,
            color: _hexToColor(textElement.color),
            fontSize: max(8.0, textElement.fontSize).toDouble(),
            fontWeight:
                textElement.isBold ? FontWeight.bold : FontWeight.normal,
            fontStyle:
                textElement.isItalic ? FontStyle.italic : FontStyle.normal,
            decoration: TextDecoration.none,
            package: null, // Ensure no package is specified for system fonts
          );
        }

        return Container(
          width: max(10.0, element.width),
          height: max(10.0, element.height),
          color: _hexToColor(textElement.backgroundColor),
          alignment: _getElementAlignment(textElement.alignment),
          padding: const EdgeInsets.all(4.0),
          child: Text(
            textElement.text.isEmpty ? ' ' : textElement.text,
            style: textStyle,
            textAlign: _getTextAlignment(textElement.alignment),
            overflow: TextOverflow.visible,
          ),
        );

      case 'camera':
        final cameraElement = element as CameraElement;
        return Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.blue,
              width: 2,
              style: BorderStyle.solid,
            ),
            color: Colors.blue.withOpacity(0.1),
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(
                  Icons.camera_alt,
                  size: min(element.width, element.height) / 3,
                  color: Colors.blue.withOpacity(0.5),
                ),
              ),
              Positioned(
                bottom: 5,
                left: 5,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  color: Colors.blue.withOpacity(0.7),
                  child: Text(
                    cameraElement.label,
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
        );

      default:
        return Container(
          color: Colors.red,
          child: Center(child: Text('Unknown element type: ${element.type}')),
        );
    }
  }

  TextAlign _getTextAlignment(String alignment) {
    switch (alignment) {
      case 'topLeft':
      case 'centerLeft':
      case 'bottomLeft':
      case 'left':
        return TextAlign.left;

      case 'topRight':
      case 'centerRight':
      case 'bottomRight':
      case 'right':
        return TextAlign.right;

      case 'topCenter':
      case 'center':
      case 'bottomCenter':
      default:
        return TextAlign.center;
    }
  }

  Alignment _getElementAlignment(String alignment) {
    switch (alignment) {
      case 'topLeft':
        return Alignment.topLeft;
      case 'topCenter':
        return Alignment.topCenter;
      case 'topRight':
        return Alignment.topRight;
      case 'centerLeft':
        return Alignment.centerLeft;
      case 'center':
        return Alignment.center;
      case 'centerRight':
        return Alignment.centerRight;
      case 'bottomLeft':
        return Alignment.bottomLeft;
      case 'bottomCenter':
        return Alignment.bottomCenter;
      case 'bottomRight':
        return Alignment.bottomRight;
      // Legacy support for old alignment values
      case 'left':
        return Alignment.centerLeft;
      case 'right':
        return Alignment.centerRight;
      default:
        return Alignment.center;
    }
  }

  Color _hexToColor(String hexColor) {
    // Handle "transparent" string explicitly
    if (hexColor == 'transparent' || hexColor.toLowerCase() == 'transparent') {
      return Colors.transparent;
    }

    // Remove hash prefix if present
    hexColor = hexColor.replaceAll('#', '');

    try {
      // Handle different hex formats
      if (hexColor.length == 6) {
        // Add FF for alpha if not present
        hexColor = 'FF$hexColor';
      } else if (hexColor.length == 8) {
        // Already has alpha, do nothing
      } else if (hexColor.length == 3) {
        // Convert 3-digit hex to 6-digit
        hexColor =
            'FF${hexColor[0]}${hexColor[0]}${hexColor[1]}${hexColor[1]}${hexColor[2]}${hexColor[2]}';
      } else {
        print('Invalid hex color format: $hexColor');
        return Colors.black; // Default fallback
      }

      return Color(int.parse(hexColor, radix: 16));
    } catch (e) {
      print('Error parsing color: $e for hexColor: $hexColor');
      return Colors.black; // Default fallback
    }
  }
}
