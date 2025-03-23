import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart'; // Add this import for HardwareKeyboard
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

    // Increase canvas dimensions to allow for elements positioned far outside
    final canvasWidth =
        layout.width.toDouble() + 5000; // Increase from 3000 to 5000
    final canvasHeight =
        layout.height.toDouble() + 5000; // Increase from 3000 to 5000

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
              if (editorProvider.selectedElement != null ||
                  editorProvider.selectedElementIds.isNotEmpty) {
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
              // Fix: Only enable panning when we're not dragging an element or using middle mouse
              panEnabled: !_isMiddleMousePanning && !editorProvider.isDragging,
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

                            // First render all non-group elements and groups
                            ..._buildNonGroupElements(layout, editorProvider),

                            // Then render selection overlays for all elements
                            // Note: This ensures overlays appear on top of all elements
                            ..._buildSelectionOverlays(editorProvider),
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

  // New method to build all non-group elements and the groups themselves
  List<Widget> _buildNonGroupElements(
    Layouts layout,
    LayoutEditorProvider editorProvider,
  ) {
    return layout.elements.map((element) {
      // Invisible element must be wrapped in Positioned to be valid in a Stack
      if (!element.isVisible) {
        // Use SizedBox.shrink() for invisible elements
        return Positioned(
          left: 0,
          top: 0,
          width: 0, // Explicitly set width
          height: 0, // Explicitly set height
          child: SizedBox.shrink(),
        );
      }

      // Ensure the element has valid dimensions
      double width = max(10.0, element.width);
      double height = max(10.0, element.height);

      // Check if this element is a group
      if (element.type == 'group') {
        final groupElement = element as GroupElement;
        final isGroupSelected = editorProvider.isElementSelected(
          groupElement.id,
        );

        return Positioned(
          left: groupElement.x,
          top: groupElement.y,
          width: width,
          height: height,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              // Support multi-selection with either Ctrl or Shift key
              final isMultiSelectModifier =
                  HardwareKeyboard.instance.isControlPressed ||
                  HardwareKeyboard.instance.isShiftPressed;

              if (!groupElement.isLocked) {
                editorProvider.selectElement(
                  groupElement,
                  addToSelection: isMultiSelectModifier,
                );
              }
            },
            onPanStart:
                groupElement.isLocked
                    ? null
                    : (details) {
                      // Start dragging the group
                      setState(() {
                        _draggedElement = groupElement;
                        _lastFocalPoint = details.localPosition;
                      });

                      // When starting a drag on any element, disable panning
                      editorProvider.startDrag();

                      // Make sure this group is selected
                      if (editorProvider.selectedElement?.id !=
                          groupElement.id) {
                        editorProvider.selectElement(groupElement);
                      }
                    },
            onPanUpdate:
                groupElement.isLocked
                    ? null
                    : (details) {
                      // Update the group position while dragging
                      if (_draggedElement?.id == groupElement.id) {
                        final delta = details.localPosition - _lastFocalPoint;
                        final newPosition =
                            Offset(groupElement.x, groupElement.y) + delta;

                        // Update the group position in the provider
                        editorProvider.updateElementPosition(
                          groupElement.id,
                          newPosition,
                        );

                        // Update the last focal point
                        setState(() {
                          _lastFocalPoint = details.localPosition;
                        });
                      }
                    },
            onPanEnd:
                groupElement.isLocked
                    ? null
                    : (details) {
                      // End dragging
                      setState(() {
                        _draggedElement = null;
                      });
                      editorProvider.stopDrag();
                    },
            child: Stack(
              children: [
                // Render the group background
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color:
                            isGroupSelected
                                ? Colors.blue.withOpacity(0.7)
                                : Colors.grey.withOpacity(0.2),
                        width: isGroupSelected ? 1.5 : 0.5,
                        style: BorderStyle.solid,
                      ),
                      color:
                          isGroupSelected
                              ? Colors.blue.withOpacity(0.05)
                              : Colors.transparent,
                    ),
                  ),
                ),

                // Group label
                Positioned(
                  top: 5,
                  left: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isGroupSelected
                              ? Colors.blue.withOpacity(0.7)
                              : Colors.grey.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      groupElement.name,
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),

                // Render all children elements inside the group
                ..._buildGroupChildElements(
                  groupElement,
                  editorProvider,
                  isGroupSelected,
                ),
              ],
            ),
          ),
        );
      } else {
        // Regular (non-group) elements
        return Positioned(
          left: element.x,
          top: element.y,
          width: width,
          height: height,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              // Support multi-selection with either Ctrl or Shift key
              final isMultiSelectModifier =
                  HardwareKeyboard.instance.isControlPressed ||
                  HardwareKeyboard.instance.isShiftPressed;

              if (!element.isLocked) {
                editorProvider.selectElement(
                  element,
                  addToSelection: isMultiSelectModifier,
                );
              }
            },
            onPanStart:
                element.isLocked
                    ? null
                    : (details) {
                      // Start dragging the element
                      setState(() {
                        _draggedElement = element;
                        _lastFocalPoint = details.localPosition;
                      });

                      // When starting a drag on any element, disable panning
                      editorProvider.startDrag();

                      // Make sure this element is selected
                      if (editorProvider.selectedElement?.id != element.id) {
                        editorProvider.selectElement(element);
                      }
                    },
            onPanUpdate:
                element.isLocked
                    ? null
                    : (details) {
                      // Update the element position while dragging
                      if (_draggedElement?.id == element.id) {
                        final delta = details.localPosition - _lastFocalPoint;
                        final newPosition =
                            Offset(element.x, element.y) + delta;

                        // Update the element position in the provider
                        editorProvider.updateElementPosition(
                          element.id,
                          newPosition,
                        );

                        // Update the last focal point
                        setState(() {
                          _lastFocalPoint = details.localPosition;
                        });
                      }
                    },
            onPanEnd:
                element.isLocked
                    ? null
                    : (details) {
                      // End dragging
                      setState(() {
                        _draggedElement = null;
                      });
                      editorProvider.stopDrag();
                    },
            child: ElementWidget(element: element),
          ),
        );
      }
    }).toList();
  }

  // Add new method to build child elements inside a group
  List<Widget> _buildGroupChildElements(
    GroupElement groupElement,
    LayoutEditorProvider editorProvider,
    bool isGroupSelected,
  ) {
    final childElements = editorProvider.getGroupChildren(groupElement.id);

    return childElements.map((childElement) {
      // Skip invisible elements
      if (!childElement.isVisible) {
        return SizedBox.shrink();
      }

      // Calculate child's position relative to group
      final relativeX = childElement.x - groupElement.x;
      final relativeY = childElement.y - groupElement.y;

      // Check if this child is selected
      final isChildSelected = editorProvider.isElementSelected(childElement.id);

      return Positioned(
        left: relativeX,
        top: relativeY,
        width: childElement.width,
        height: childElement.height,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            // If the group is already selected, select the child element instead
            if (isGroupSelected || isChildSelected) {
              final isMultiSelectModifier =
                  HardwareKeyboard.instance.isControlPressed ||
                  HardwareKeyboard.instance.isShiftPressed;

              if (!childElement.isLocked) {
                editorProvider.selectElement(
                  childElement,
                  addToSelection: isMultiSelectModifier,
                );
              }
            }
          },
          onPanStart:
              childElement.isLocked
                  ? null
                  : (details) {
                    // Only allow dragging the child if the group is selected first
                    // or the child itself is already selected
                    if (isGroupSelected || isChildSelected) {
                      // Start dragging the child element
                      setState(() {
                        _draggedElement = childElement;
                        _lastFocalPoint = details.localPosition;
                      });

                      // When starting a drag, disable panning
                      editorProvider.startDrag();

                      // Select the child element if not already selected
                      if (editorProvider.selectedElement?.id !=
                          childElement.id) {
                        editorProvider.selectElement(childElement);
                      }
                    }
                  },
          onPanUpdate:
              childElement.isLocked
                  ? null
                  : (details) {
                    // Update the child element position while dragging
                    if (_draggedElement?.id == childElement.id) {
                      final delta = details.localPosition - _lastFocalPoint;

                      // Calculate the absolute position (not relative to group)
                      final newPosition =
                          Offset(childElement.x, childElement.y) + delta;

                      // Update the child element position in the provider
                      editorProvider.updateElementPosition(
                        childElement.id,
                        newPosition,
                      );

                      // Update the last focal point
                      setState(() {
                        _lastFocalPoint = details.localPosition;
                      });
                    }
                  },
          onPanEnd:
              childElement.isLocked
                  ? null
                  : (details) {
                    // End dragging
                    setState(() {
                      _draggedElement = null;
                    });
                    editorProvider.stopDrag();
                  },
          child: ElementWidget(element: childElement, isGroupChild: true),
        ),
      );
    }).toList();
  }

  // New method to build selection overlays
  List<Widget> _buildSelectionOverlays(LayoutEditorProvider editorProvider) {
    if (editorProvider.layout == null) return [];

    List<Widget> overlays = [];

    for (final element in editorProvider.selectedElements) {
      // Skip invisible elements
      if (!element.isVisible) continue;

      // Add selection overlay
      overlays.add(
        Positioned(
          left: element.x,
          top: element.y,
          width: max(10.0, element.width),
          height: max(10.0, element.height),
          child: custom_overlay.SelectionOverlay(
            element: element,
            isPrimary: element.id == editorProvider.selectedElement?.id,
            onResize: (size) {
              editorProvider.updateElementSize(element.id, size);
            },
            onRotate: (rotation) {
              editorProvider.updateElementRotation(element.id, rotation);
            },
          ),
        ),
      );
    }

    return overlays;
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
