import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../../models/layouts.dart';
import '../../providers/layout_editor.dart';

class SelectionOverlay extends StatelessWidget {
  final LayoutElement element;
  final Function(Size) onResize;
  final Function(double) onRotate;
  final bool isPrimary;

  const SelectionOverlay({
    super.key,
    required this.element,
    required this.onResize,
    required this.onRotate,
    this.isPrimary = true,
  });

  @override
  Widget build(BuildContext context) {
    // Get the current scale from the provider to maintain consistent handle sizes
    final editorProvider = Provider.of<LayoutEditorProvider>(context);
    final currentScale =
        editorProvider.transformationController.value.getMaxScaleOnAxis();

    // Calculate the inverse scale to counter the zoom effect
    final inverseScale = 1 / currentScale;

    // Define colors based on primary selection
    final borderColor = isPrimary ? Colors.blue : Colors.lightBlue;
    final fillColor =
        isPrimary
            ? Colors.blue.withOpacity(0.03)
            : Colors.lightBlue.withOpacity(0.02);

    return Stack(
      fit: StackFit.passthrough, // Ensure the stack properly fits its size
      children: [
        // Selection border - make it a non-interactive overlay
        Positioned.fill(
          child: IgnorePointer(
            // Use IgnorePointer to make sure this doesn't capture touches
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: borderColor,
                  width: 2.0 * inverseScale,
                ),
                // Add a subtle glow effect
                boxShadow: [
                  BoxShadow(
                    color: borderColor.withOpacity(0.3),
                    blurRadius: 4 * inverseScale,
                    spreadRadius: 1 * inverseScale,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Very light overlay to show what's selected
        Positioned.fill(
          child: IgnorePointer(child: Container(color: fillColor)),
        ),

        // The resize handles should remain interactive
        if (isPrimary && !element.isLocked) ...[
          _buildResizeHandle(Alignment.topLeft, context),
          _buildResizeHandle(Alignment.topRight, context),
          _buildResizeHandle(Alignment.bottomLeft, context),
          _buildResizeHandle(Alignment.bottomRight, context),

          // Rotation handle
          Positioned(
            left: element.width / 2 - 6,
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
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 2,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Rotation line
          Positioned(
            left: element.width / 2,
            top: -30,
            bottom: null,
            right: null,
            width: 1.5,
            height: 30,
            child: Container(color: Colors.blue),
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
      left = element.width - 6; // Adjusted for larger handle
    }

    if (alignment == Alignment.bottomLeft ||
        alignment == Alignment.bottomRight) {
      top = element.height - 6; // Adjusted for larger handle
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
          width: 12, // Larger handle
          height: 12, // Larger handle
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.blue, width: 1.5),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 2,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
