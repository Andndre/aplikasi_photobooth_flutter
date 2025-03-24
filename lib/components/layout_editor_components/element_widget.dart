import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../models/layouts.dart';
import '../../providers/layout_editor.dart';
import 'package:google_fonts/google_fonts.dart';

class ElementWidget extends StatelessWidget {
  final LayoutElement element;
  final bool isGroupChild;

  const ElementWidget({
    super.key,
    required this.element,
    this.isGroupChild = false,
  });

  @override
  Widget build(BuildContext context) {
    final editorProvider = Provider.of<LayoutEditorProvider>(context);
    final isSelected = editorProvider.isElementSelected(element.id);

    // Check if we need to put a placeholder while fonts are loading
    final isTextElement = element.type == 'text';
    final isLoadingFonts = editorProvider.isLoadingFonts;
    final initialFontLoadComplete = editorProvider.initialFontLoadComplete;

    // Use a placeholder during initial font load for text elements
    if (isTextElement && isLoadingFonts && !initialFontLoadComplete) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(
            color:
                isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.withOpacity(0.2),
            width: isSelected ? 2.0 : 1.0,
          ),
          color: Colors.grey.withOpacity(0.1),
        ),
        child: const Center(
          child: Text('Loading font...', style: TextStyle(fontSize: 10)),
        ),
      );
    }

    // Regular element rendering
    switch (element.type) {
      case 'image':
        return _buildImageElement(element as ImageElement, isSelected, context);
      case 'text':
        return _buildTextElement(element as TextElement, isSelected, context);
      case 'camera':
        return _buildCameraElement(
          element as CameraElement,
          isSelected,
          context,
        );
      default:
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.red),
            color: Colors.red.withOpacity(0.2),
          ),
          child: const Center(child: Text('Unknown element type')),
        );
    }
  }

  Widget _buildImageElement(
    ImageElement element,
    bool isSelected,
    BuildContext context,
  ) {
    final file = File(element.path);
    return file.existsSync()
        ? Opacity(
          opacity: element.opacity,
          child: Image.file(
            file,
            fit: element.aspectRatioLocked ? BoxFit.contain : BoxFit.fill,
            width: element.width,
            height: element.height,
          ),
        )
        : Container(
          color: Colors.grey[300],
          child: const Center(child: Icon(Icons.image_not_supported, size: 24)),
        );
  }

  Widget _buildCameraElement(
    CameraElement element,
    bool isSelected,
    BuildContext context,
  ) {
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
                element.label,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextElement(
    TextElement element,
    bool isSelected,
    BuildContext context,
  ) {
    TextStyle textStyle;

    try {
      // Properly handle Google Fonts
      if (element.isGoogleFont) {
        try {
          textStyle = GoogleFonts.getFont(
            element.fontFamily,
            color: _hexToColor(element.color),
            fontSize: element.fontSize,
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
            color: _hexToColor(element.color),
            fontSize: element.fontSize,
            fontWeight: element.isBold ? FontWeight.bold : FontWeight.normal,
            fontStyle: element.isItalic ? FontStyle.italic : FontStyle.normal,
          );
        }
      } else {
        // System font
        textStyle = TextStyle(
          fontFamily: element.fontFamily,
          color: _hexToColor(element.color),
          fontSize: element.fontSize,
          fontWeight: element.isBold ? FontWeight.bold : FontWeight.normal,
          fontStyle: element.isItalic ? FontStyle.italic : FontStyle.normal,
        );
      }

      // Container with proper alignment and background
      return Container(
        decoration: BoxDecoration(
          color:
              element.backgroundColor != 'transparent'
                  ? _hexToColor(element.backgroundColor)
                  : Colors.transparent,
          border:
              isSelected
                  ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2.0,
                  )
                  : null,
        ),
        child: Transform.rotate(
          angle: (element.rotation * 3.14159) / 180,
          child: Align(
            alignment: _getAlignment(element.alignment),
            child: Text(
              element.text,
              style: textStyle,
              textAlign: _getTextAlign(element.alignment),
              overflow: TextOverflow.visible,
            ),
          ),
        ),
      );
    } catch (e) {
      // Fallback rendering for error cases
      print('Error rendering text element: $e');
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.red),
          color: Colors.red.withOpacity(0.2),
        ),
        child: Center(
          child: Text(
            'Error rendering text: ${e.toString()}',
            style: const TextStyle(fontSize: 10, color: Colors.red),
          ),
        ),
      );
    }
  }

  TextAlign _getTextAlign(String alignment) {
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

  Alignment _getAlignment(String alignment) {
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
