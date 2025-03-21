import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:math'; // Make sure to import this
import '../../models/layouts.dart';

class ElementWidget extends StatelessWidget {
  final LayoutElement element;

  const ElementWidget({super.key, required this.element});

  @override
  Widget build(BuildContext context) {
    // Ensure width and height are at least 10 pixels
    final safeWidth = max(10.0, element.width);
    final safeHeight = max(10.0, element.height);

    return Transform.rotate(
      angle: element.rotation * (pi / 180),
      child: SizedBox(
        width: safeWidth,
        height: safeHeight,
        child: _buildElementContent(),
      ),
    );
  }

  Widget _buildElementContent() {
    switch (element.type) {
      case 'image':
        final imageElement = element as ImageElement;
        final file = File(imageElement.path);
        return file.existsSync()
            ? Opacity(
              opacity: imageElement.opacity,
              child: Image.file(
                file,
                fit: BoxFit.fill,
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
        return Container(
          width: max(10.0, element.width),
          height: max(10.0, element.height),
          color: _hexToColor(textElement.backgroundColor),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(4.0),
          child: Text(
            textElement.text.isEmpty
                ? ' '
                : textElement.text, // Ensure text is never empty
            style: TextStyle(
              color: _hexToColor(textElement.color),
              fontSize:
                  max(
                    8.0,
                    textElement.fontSize,
                  ).toDouble(), // Fixed: ensuring it's a double
              fontWeight:
                  textElement.isBold ? FontWeight.bold : FontWeight.normal,
              fontStyle:
                  textElement.isItalic ? FontStyle.italic : FontStyle.normal,
              fontFamily:
                  textElement.fontFamily.isEmpty
                      ? 'Arial'
                      : textElement.fontFamily,
              decoration: TextDecoration.none,
            ),
            textAlign: _getTextAlignment(textElement.alignment),
            overflow: TextOverflow.visible, // Use visible instead of clip
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
      case 'left':
        return TextAlign.left;
      case 'right':
        return TextAlign.right;
      case 'center':
      default:
        return TextAlign.center;
    }
  }

  Color _hexToColor(String hexColor) {
    if (hexColor == 'transparent') return Colors.transparent;

    hexColor = hexColor.replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    return Color(int.parse(hexColor, radix: 16));
  }
}
