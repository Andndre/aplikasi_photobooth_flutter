import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/gestures.dart';
import 'dart:math';
import '../../models/layouts.dart';
import '../../providers/layout_editor.dart';
import './element_widget.dart';
import './selection_overlay.dart' as custom_overlay;

class CanvasWorkspace extends StatefulWidget {
  const CanvasWorkspace({super.key});

  @override
  CanvasWorkspaceState createState() => CanvasWorkspaceState();
}

class CanvasWorkspaceState extends State<CanvasWorkspace> {
  LayoutElement? _draggedElement;
  Offset _lastFocalPoint = Offset.zero;
  bool _isMiddleMousePanning = false;
  Offset _middleMouseStartPoint = Offset.zero;
  Matrix4 _previousTransform = Matrix4.identity();

  // Add a key for the InteractiveViewer
  final _interactiveViewerKey = GlobalKey();

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

    // Calculate reasonable canvas dimensions with padding
    final canvasWidth =
        layout.width.toDouble() + 3000; // Add extra space for panning
    final canvasHeight = layout.height.toDouble() + 3000;

    // Calculate initial position to center the canvas
    final canvasCenterX = canvasWidth / 2;
    final canvasCenterY = canvasHeight / 2;

    return Listener(
      onPointerDown: (PointerDownEvent event) {
        // Check if middle mouse button (button index 1) is pressed
        if (event.buttons == 4) {
          // 4 represents middle mouse button
          setState(() {
            _isMiddleMousePanning = true;
            _middleMouseStartPoint = event.position;
            _previousTransform = Matrix4.copy(
              editorProvider.transformationController.value,
            );
          });
        }
      },
      onPointerMove: (PointerMoveEvent event) {
        if (_isMiddleMousePanning) {
          // Calculate the difference between current and start positions
          final delta = event.position - _middleMouseStartPoint;

          // To avoid floating point issues, round small deltas to zero
          final dx = delta.dx.abs() < 0.01 ? 0.0 : delta.dx;
          final dy = delta.dy.abs() < 0.01 ? 0.0 : delta.dy;

          // Create a new transform by applying the translation
          final newTransform = Matrix4.copy(_previousTransform);

          // Apply the translation with better scaling
          final scale = editorProvider.scale;
          newTransform.translate(dx / scale, dy / scale);

          // Apply the new transform
          editorProvider.transformationController.value = newTransform;
        }
      },
      onPointerUp: (PointerUpEvent event) {
        if (_isMiddleMousePanning) {
          setState(() {
            _isMiddleMousePanning = false;
          });
        }
      },
      onPointerSignal: (PointerSignalEvent event) {
        // Handle mouse wheel for zooming
        if (event is PointerScrollEvent) {
          // Don't handle zoom if it's a horizontal scroll
          if (event.scrollDelta.dy == 0) return;

          // Get current scale for smoother transitions
          final currentScale =
              editorProvider.transformationController.value.getMaxScaleOnAxis();

          // Calculate zoom factor with improved control
          // Using fixed ratios instead of dynamic calculation for more predictable behavior
          final zoomFactor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;

          // Calculate target scale with proper constraints
          final targetScale = (currentScale * zoomFactor).clamp(0.1, 5.0);

          // Apply zoom centered on mouse position
          _applyZoomWithBetterPrecision(
            editorProvider,
            targetScale,
            event.localPosition,
            currentScale,
          );

          // Ensure canvas stays in view after zooming
          editorProvider.ensureCanvasVisible();
        }
      },
      child: MouseRegion(
        cursor:
            _isMiddleMousePanning
                ? SystemMouseCursors.grabbing
                : SystemMouseCursors.basic,
        child: Container(
          color: Colors.grey[300],
          // Wrap with GestureDetector to detect clicks on empty areas
          child: GestureDetector(
            onTap: () {
              // Deselect any selected element when clicking on empty area
              if (editorProvider.selectedElement != null) {
                editorProvider.selectElement(null);
              }
            },
            child: InteractiveViewer(
              key: _interactiveViewerKey,
              transformationController: editorProvider.transformationController,
              constrained: false,
              boundaryMargin: EdgeInsets.all(max(canvasWidth, canvasHeight)),
              minScale:
                  0.1, // Increased minimum scale to prevent excessive zoom out
              maxScale: 5.0,
              panEnabled:
                  !_isMiddleMousePanning, // Disable standard panning when middle mouse is active
              onInteractionUpdate: (details) {
                editorProvider.setScale(
                  editorProvider.transformationController.value
                      .getMaxScaleOnAxis(),
                );
              },
              onInteractionEnd: (details) {
                // Ensure canvas stays in view after interaction
                editorProvider.ensureCanvasVisible();
              },
              child: SizedBox(
                width: canvasWidth,
                height: canvasHeight,
                child: Stack(
                  children: [
                    // Background pattern to help with orientation (optional)
                    Positioned.fill(
                      child: Container(
                        color: Colors.grey[200],
                        child: CustomPaint(painter: BackgroundPatternPainter()),
                      ),
                    ),

                    // Centered canvas
                    Positioned(
                      left: canvasCenterX - layout.width / 2,
                      top: canvasCenterY - layout.height / 2,
                      child: Container(
                        width: layout.width.toDouble(),
                        height: layout.height.toDouble(),
                        decoration: BoxDecoration(
                          color: _hexToColor(layout.backgroundColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Grid (if enabled)
                            if (editorProvider.showGrid)
                              Positioned.fill(
                                child: CustomPaint(painter: GridPainter()),
                              ),

                            // Elements
                            ...layout.elements.map((element) {
                              if (!element.isVisible) return const SizedBox();

                              return Positioned(
                                left: element.x,
                                top: element.y,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
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
                                              _lastFocalPoint =
                                                  details.localPosition;
                                            });
                                            editorProvider.startDrag();
                                          },
                                  onPanUpdate:
                                      element.isLocked
                                          ? null
                                          : (details) {
                                            if (_draggedElement?.id ==
                                                element.id) {
                                              final delta =
                                                  details.localPosition -
                                                  _lastFocalPoint;
                                              final newPosition =
                                                  Offset(element.x, element.y) +
                                                  delta;
                                              editorProvider
                                                  .updateElementPosition(
                                                    element.id,
                                                    newPosition,
                                                  );
                                              setState(() {
                                                _lastFocalPoint =
                                                    details.localPosition;
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
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // New method for better zoom precision
  void _applyZoomWithBetterPrecision(
    LayoutEditorProvider provider,
    double targetScale,
    Offset focalPoint,
    double currentScale,
  ) {
    // Get the current matrix
    final matrix = provider.transformationController.value;

    // Convert the focal point to scene coordinates before scaling
    final focalPointScene = provider.transformationController.toScene(
      focalPoint,
    );

    // Create a new matrix for this transformation
    final newMatrix =
        Matrix4.identity()
          ..setTranslationRaw(0, 0, 0)
          ..translate(focalPointScene.dx, focalPointScene.dy)
          ..scale(targetScale / currentScale)
          ..translate(-focalPointScene.dx, -focalPointScene.dy);

    // Combine the matrices using multiplication
    final combinedMatrix = matrix * newMatrix;

    // Update the controller with the new matrix
    provider.transformationController.value = combinedMatrix;

    // Update provider's scale value
    provider.setScale(targetScale);
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

// Background pattern to help users understand when they're outside the canvas
class BackgroundPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.grey.withOpacity(0.2)
          ..strokeWidth = 1.0;

    const spacing = 50.0;

    for (double i = 0; i < size.width; i += spacing) {
      for (double j = 0; j < size.height; j += spacing) {
        canvas.drawCircle(Offset(i, j), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
