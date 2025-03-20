import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../../models/layouts.dart';
import '../../providers/layout_editor.dart';

class SelectionOverlay extends StatelessWidget {
  final LayoutElement element;
  final Function(Size) onResize;
  final Function(double) onRotate;

  const SelectionOverlay({
    Key? key,
    required this.element,
    required this.onResize,
    required this.onRotate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Selection border
        Container(
          width: element.width,
          height: element.height,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue, width: 1),
          ),
        ),

        // Resize handles
        if (!element.isLocked) ...[
          _buildResizeHandle(Alignment.topLeft, context),
          _buildResizeHandle(Alignment.topRight, context),
          _buildResizeHandle(Alignment.bottomLeft, context),
          _buildResizeHandle(Alignment.bottomRight, context),

          // Rotation handle
          Positioned(
            left: element.width / 2 - 5,
            top: -30,
            child: GestureDetector(
              onPanUpdate: (details) {
                final center = Offset(element.width / 2, element.height / 2);
                final position = details.localPosition;
                final angle = atan2(
                  position.dy - center.dy,
                  position.dx - center.dx,
                );
                onRotate(angle * (180 / pi));
              },
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),

          // Rotation line
          Positioned(
            left: element.width / 2,
            top: -20,
            child: Container(width: 1, height: 20, color: Colors.blue),
          ),
        ],
      ],
    );
  }

  Widget _buildResizeHandle(Alignment alignment, BuildContext context) {
    final editorProvider = Provider.of<LayoutEditorProvider>(
      context,
      listen: false,
    );

    double left = 0;
    double top = 0;

    if (alignment == Alignment.topRight || alignment == Alignment.bottomRight) {
      left = element.width - 5;
    }

    if (alignment == Alignment.bottomLeft ||
        alignment == Alignment.bottomRight) {
      top = element.height - 5;
    }

    Offset startPosition = Offset.zero;
    Size startSize = Size.zero;

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onPanStart: (details) {
          startPosition = details.globalPosition;
          startSize = Size(element.width, element.height);
          editorProvider.startResize();
        },
        onPanUpdate: (details) {
          final dx = details.globalPosition.dx - startPosition.dx;
          final dy = details.globalPosition.dy - startPosition.dy;

          double newWidth = startSize.width;
          double newHeight = startSize.height;

          if (alignment == Alignment.topLeft ||
              alignment == Alignment.bottomLeft) {
            newWidth = startSize.width - dx;
          } else {
            newWidth = startSize.width + dx;
          }

          if (alignment == Alignment.topLeft ||
              alignment == Alignment.topRight) {
            newHeight = startSize.height - dy;
          } else {
            newHeight = startSize.height + dy;
          }

          newWidth = max(10, newWidth);
          newHeight = max(10, newHeight);

          onResize(Size(newWidth, newHeight));
        },
        onPanEnd: (details) {
          editorProvider.stopResize();
        },
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.blue),
          ),
        ),
      ),
    );
  }
}
