import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:math';
import '../../models/layouts.dart';
import '../../providers/layout_editor.dart';
import './element_widget.dart';
// Rename the import to avoid naming conflict with Flutter's SelectionOverlay
import './selection_overlay.dart' as custom_overlay;

class CanvasWorkspace extends StatefulWidget {
  const CanvasWorkspace({Key? key}) : super(key: key);

  @override
  CanvasWorkspaceState createState() => CanvasWorkspaceState();
}

class CanvasWorkspaceState extends State<CanvasWorkspace> {
  LayoutElement? _draggedElement;
  Offset _lastFocalPoint = Offset.zero;
  Size? _lastSize;

  @override
  void initState() {
    super.initState();
    // No need to create a local controller since we'll use the one from the provider
  }

  @override
  Widget build(BuildContext context) {
    final editorProvider = Provider.of<LayoutEditorProvider>(context);
    final layout = editorProvider.layout;

    if (layout == null) {
      return const Center(child: Text('No layout loaded'));
    }

    return Container(
      color: Colors.grey[300],
      child: InteractiveViewer(
        transformationController: editorProvider.transformationController,
        constrained: false,
        boundaryMargin: const EdgeInsets.all(100),
        minScale: 0.1,
        maxScale: 5.0,
        onInteractionUpdate: (details) {
          editorProvider.setScale(
            editorProvider.transformationController.value.getMaxScaleOnAxis(),
          );
        },
        child: Stack(
          children: [
            // Canvas background
            Container(
              width: layout.width.toDouble(),
              height: layout.height.toDouble(),
              color: _hexToColor(layout.backgroundColor),
              child: CustomPaint(
                painter: editorProvider.showGrid ? GridPainter() : null,
              ),
            ),

            // Layout elements
            ...layout.elements.map((element) {
              if (!element.isVisible) return const SizedBox();

              return Positioned(
                left: element.x,
                top: element.y,
                child: GestureDetector(
                  onTap: () {
                    if (!element.isLocked) {
                      editorProvider.selectElement(element);
                    }
                  },
                  onPanStart:
                      element.isLocked
                          ? null
                          : (details) {
                            setState(() {
                              _draggedElement = element;
                              _lastFocalPoint = details.localPosition;
                            });
                            editorProvider.startDrag();
                          },
                  onPanUpdate:
                      element.isLocked
                          ? null
                          : (details) {
                            if (_draggedElement?.id == element.id) {
                              final delta =
                                  details.localPosition - _lastFocalPoint;
                              final newPosition =
                                  Offset(element.x, element.y) + delta;
                              editorProvider.updateElementPosition(
                                element.id,
                                newPosition,
                              );
                              setState(() {
                                _lastFocalPoint = details.localPosition;
                              });
                            }
                          },
                  onPanEnd:
                      element.isLocked
                          ? null
                          : (details) {
                            setState(() {
                              _draggedElement = null;
                            });
                            editorProvider.stopDrag();
                          },
                  child: ElementWidget(element: element),
                ),
              );
            }).toList(),

            // Selection overlay
            if (editorProvider.selectedElement != null)
              Positioned(
                left: editorProvider.selectedElement!.x,
                top: editorProvider.selectedElement!.y,
                child: custom_overlay.SelectionOverlay(
                  element: editorProvider.selectedElement!,
                  onResize: (size) {
                    editorProvider.updateElementSize(
                      editorProvider.selectedElement!.id,
                      size,
                    );
                  },
                  onRotate: (rotation) {
                    editorProvider.updateElementRotation(
                      editorProvider.selectedElement!.id,
                      rotation,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
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

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const gridSize = 20.0;
    final paint =
        Paint()
          ..color = Colors.grey.withOpacity(
            0.5,
          ) // Use withOpacity instead of withValues
          ..strokeWidth = 0.5;

    for (double i = 0; i <= size.width; i += gridSize) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }

    for (double i = 0; i <= size.height; i += gridSize) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
