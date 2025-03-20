import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:vector_math/vector_math_64.dart'; // Add this import for Vector3
import '../models/layouts.dart';
import 'dart:io';

enum EditMode { select, move, text, image, camera }

class LayoutEditorProvider with ChangeNotifier {
  Layouts? _layout;
  LayoutElement? _selectedElement;
  EditMode _editMode = EditMode.select;
  List<LayoutElement> _clipboard = [];
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  bool _isDragging = false;
  bool _isResizing = false;
  bool _showGrid = true;
  bool _snapToGrid = true;
  final _uuid = Uuid();

  // Add a TransformationController
  final TransformationController transformationController =
      TransformationController();

  Layouts? get layout => _layout;
  LayoutElement? get selectedElement => _selectedElement;
  EditMode get editMode => _editMode;
  double get scale => _scale;
  Offset get offset => _offset;
  bool get isDragging => _isDragging;
  bool get isResizing => _isResizing;
  bool get showGrid => _showGrid;
  bool get snapToGrid => _snapToGrid;

  void setLayout(Layouts layout) {
    _layout = layout;
    _selectedElement = null;
    _scale = 1.0;
    _offset = Offset.zero;
    notifyListeners();
  }

  void setEditMode(EditMode mode) {
    _editMode = mode;
    notifyListeners();
  }

  void selectElement(LayoutElement? element) {
    _selectedElement = element;
    notifyListeners();
  }

  void toggleGrid() {
    _showGrid = !_showGrid;
    notifyListeners();
  }

  void toggleSnapToGrid() {
    _snapToGrid = !_snapToGrid;
    notifyListeners();
  }

  void startDrag() {
    _isDragging = true;
    notifyListeners();
  }

  void stopDrag() {
    _isDragging = false;
    notifyListeners();
  }

  void startResize() {
    _isResizing = true;
    notifyListeners();
  }

  void stopResize() {
    _isResizing = false;
    notifyListeners();
  }

  void setScale(double newScale) {
    _scale = newScale.clamp(0.1, 5.0);
    notifyListeners();
  }

  void setOffset(Offset newOffset) {
    _offset = newOffset;
    notifyListeners();
  }

  void addImageElement(String path, {Offset? position, Size? size}) {
    if (_layout == null) return;

    final file = File(path);
    if (!file.existsSync()) return;

    final imageSize = size ?? const Size(200, 200);
    final pos =
        position ??
        Offset(
          (_layout!.width / 2) - (imageSize.width / 2),
          (_layout!.height / 2) - (imageSize.height / 2),
        );

    final newElement = ImageElement(
      id: _uuid.v4(),
      x: pos.dx,
      y: pos.dy,
      width: imageSize.width,
      height: imageSize.height,
      path: path,
    );

    _layout!.elements.add(newElement);
    _selectedElement = newElement;
    notifyListeners();
  }

  void addTextElement({String? text, Offset? position, Size? size}) {
    if (_layout == null) return;

    final textSize = size ?? const Size(200, 50);
    final pos =
        position ??
        Offset(
          (_layout!.width / 2) - (textSize.width / 2),
          (_layout!.height / 2) - (textSize.height / 2),
        );

    final newElement = TextElement(
      id: _uuid.v4(),
      x: pos.dx,
      y: pos.dy,
      width: textSize.width,
      height: textSize.height,
      text: text ?? 'New Text',
    );

    _layout!.elements.add(newElement);
    _selectedElement = newElement;
    notifyListeners();
  }

  void addCameraElement({Offset? position, Size? size}) {
    if (_layout == null) return;

    final cameraSize = size ?? const Size(300, 300);
    final pos =
        position ??
        Offset(
          (_layout!.width / 2) - (cameraSize.width / 2),
          (_layout!.height / 2) - (cameraSize.height / 2),
        );

    // Count existing camera elements for label
    final cameraCount =
        _layout!.elements.where((e) => e.type == 'camera').length;

    final newElement = CameraElement(
      id: _uuid.v4(),
      x: pos.dx,
      y: pos.dy,
      width: cameraSize.width,
      height: cameraSize.height,
      label: 'Photo Spot ${cameraCount + 1}',
    );

    _layout!.elements.add(newElement);
    _selectedElement = newElement;
    notifyListeners();
  }

  void updateElementPosition(String id, Offset position) {
    if (_layout == null) return;

    final elementIndex = _layout!.elements.indexWhere((e) => e.id == id);
    if (elementIndex < 0) return;

    final element = _layout!.elements[elementIndex];

    // Ensure element isn't locked
    if (element.isLocked) return;

    // Apply snapping if enabled
    double dx = position.dx;
    double dy = position.dy;

    if (_snapToGrid) {
      const gridSize = 10.0;
      dx = (dx / gridSize).round() * gridSize;
      dy = (dy / gridSize).round() * gridSize;
    }

    // Ensure element stays within layout bounds
    dx = dx.clamp(0, _layout!.width - element.width);
    dy = dy.clamp(0, _layout!.height - element.height);

    // Update element position
    element.x = dx;
    element.y = dy;

    // Update selected element reference if needed
    if (_selectedElement?.id == id) {
      _selectedElement = element;
    }

    // Explicitly notify listeners to ensure UI updates
    notifyListeners();
  }

  void updateElementSize(String id, Size size) {
    if (_layout == null) return;

    final elementIndex = _layout!.elements.indexWhere((e) => e.id == id);
    if (elementIndex < 0) return;

    final element = _layout!.elements[elementIndex];

    // Apply snapping if enabled
    double width = size.width;
    double height = size.height;

    if (_snapToGrid) {
      const gridSize = 10.0;
      width = (width / gridSize).round() * gridSize;
      height = (height / gridSize).round() * gridSize;
    }

    // Ensure minimum size
    width = width.clamp(10, _layout!.width - element.x);
    height = height.clamp(10, _layout!.height - element.y);

    element.width = width;
    element.height = height;

    if (_selectedElement?.id == id) {
      _selectedElement = element;
    }

    notifyListeners();
  }

  void updateElementRotation(String id, double rotation) {
    if (_layout == null) return;

    final elementIndex = _layout!.elements.indexWhere((e) => e.id == id);
    if (elementIndex < 0) return;

    final element = _layout!.elements[elementIndex];
    element.rotation = rotation;

    if (_selectedElement?.id == id) {
      _selectedElement = element;
    }

    notifyListeners();
  }

  void updateTextElement(
    String id, {
    String? text,
    String? fontFamily,
    double? fontSize,
    String? color,
    String? backgroundColor,
    bool? isBold,
    bool? isItalic,
    String? alignment,
  }) {
    if (_layout == null) return;

    final elementIndex = _layout!.elements.indexWhere((e) => e.id == id);
    if (elementIndex < 0 || _layout!.elements[elementIndex].type != 'text')
      return;

    final element = _layout!.elements[elementIndex] as TextElement;

    if (text != null) element.text = text;
    if (fontFamily != null) element.fontFamily = fontFamily;
    if (fontSize != null) element.fontSize = fontSize;
    if (color != null) element.color = color;
    if (backgroundColor != null) element.backgroundColor = backgroundColor;
    if (isBold != null) element.isBold = isBold;
    if (isItalic != null) element.isItalic = isItalic;
    if (alignment != null) element.alignment = alignment;

    if (_selectedElement?.id == id) {
      _selectedElement = element;
    }

    notifyListeners();
  }

  void updateImageElement(String id, {String? path, double? opacity}) {
    if (_layout == null) return;

    final elementIndex = _layout!.elements.indexWhere((e) => e.id == id);
    if (elementIndex < 0 || _layout!.elements[elementIndex].type != 'image')
      return;

    final element = _layout!.elements[elementIndex] as ImageElement;

    if (path != null) element.path = path;
    if (opacity != null) element.opacity = opacity;

    if (_selectedElement?.id == id) {
      _selectedElement = element;
    }

    notifyListeners();
  }

  void updateCameraElement(String id, {String? label}) {
    if (_layout == null) return;

    final elementIndex = _layout!.elements.indexWhere((e) => e.id == id);
    if (elementIndex < 0 || _layout!.elements[elementIndex].type != 'camera')
      return;

    final element = _layout!.elements[elementIndex] as CameraElement;

    if (label != null) element.label = label;

    if (_selectedElement?.id == id) {
      _selectedElement = element;
    }

    notifyListeners();
  }

  void toggleElementLock(String id) {
    if (_layout == null) return;

    final elementIndex = _layout!.elements.indexWhere((e) => e.id == id);
    if (elementIndex < 0) return;

    final element = _layout!.elements[elementIndex];
    element.isLocked = !element.isLocked;

    if (_selectedElement?.id == id) {
      _selectedElement = element;
    }

    notifyListeners();
  }

  void toggleElementVisibility(String id) {
    if (_layout == null) return;

    final elementIndex = _layout!.elements.indexWhere((e) => e.id == id);
    if (elementIndex < 0) return;

    final element = _layout!.elements[elementIndex];
    element.isVisible = !element.isVisible;

    if (_selectedElement?.id == id) {
      _selectedElement = element;
    }

    notifyListeners();
  }

  void deleteElement(String id) {
    if (_layout == null) return;

    final elementIndex = _layout!.elements.indexWhere((e) => e.id == id);
    if (elementIndex < 0) return;

    _layout!.elements.removeAt(elementIndex);

    if (_selectedElement?.id == id) {
      _selectedElement = null;
    }

    notifyListeners();
  }

  void copyElement(String id) {
    if (_layout == null) return;

    final element = _layout!.elements.firstWhere(
      (e) => e.id == id,
      orElse: () => throw Exception('Element not found'),
    );

    _clipboard = [element];
    notifyListeners();
  }

  void pasteElement() {
    if (_layout == null || _clipboard.isEmpty) return;

    for (final sourceElement in _clipboard) {
      late LayoutElement newElement;

      switch (sourceElement.type) {
        case 'image':
          final source = sourceElement as ImageElement;
          newElement = ImageElement(
            id: _uuid.v4(),
            x: source.x + 20,
            y: source.y + 20,
            width: source.width,
            height: source.height,
            path: source.path,
            opacity: source.opacity,
            rotation: source.rotation,
          );
          break;
        case 'text':
          final source = sourceElement as TextElement;
          newElement = TextElement(
            id: _uuid.v4(),
            x: source.x + 20,
            y: source.y + 20,
            width: source.width,
            height: source.height,
            text: source.text,
            fontFamily: source.fontFamily,
            fontSize: source.fontSize,
            color: source.color,
            backgroundColor: source.backgroundColor,
            isBold: source.isBold,
            isItalic: source.isItalic,
            alignment: source.alignment,
            rotation: source.rotation,
          );
          break;
        case 'camera':
          final source = sourceElement as CameraElement;
          final cameraCount =
              _layout!.elements.where((e) => e.type == 'camera').length;
          newElement = CameraElement(
            id: _uuid.v4(),
            x: source.x + 20,
            y: source.y + 20,
            width: source.width,
            height: source.height,
            label: 'Photo Spot ${cameraCount + 1}',
            rotation: source.rotation,
          );
          break;
      }

      _layout!.elements.add(newElement);
      _selectedElement = newElement;
    }

    notifyListeners();
  }

  void updateLayoutBackground(String color) {
    if (_layout == null) return;

    print("Updating background color to: $color");

    // Ensure color is properly formatted
    if (!color.startsWith('#')) {
      color = '#$color';
    }

    // Update layout background
    _layout!.backgroundColor = color;

    // Force notification to all listeners
    notifyListeners();
  }

  void bringToFront(String id) {
    if (_layout == null) return;

    final elementIndex = _layout!.elements.indexWhere((e) => e.id == id);
    if (elementIndex < 0) return;

    final element = _layout!.elements.removeAt(elementIndex);
    _layout!.elements.add(element);

    notifyListeners();
  }

  void sendToBack(String id) {
    if (_layout == null) return;

    final elementIndex = _layout!.elements.indexWhere((e) => e.id == id);
    if (elementIndex < 0) return;

    final element = _layout!.elements.removeAt(elementIndex);
    _layout!.elements.insert(0, element);

    notifyListeners();
  }

  void moveForward(String id) {
    if (_layout == null) return;

    final elementIndex = _layout!.elements.indexWhere((e) => e.id == id);
    if (elementIndex < 0 || elementIndex >= _layout!.elements.length - 1)
      return;

    final element = _layout!.elements.removeAt(elementIndex);
    _layout!.elements.insert(elementIndex + 1, element);

    notifyListeners();
  }

  void moveBackward(String id) {
    if (_layout == null) return;

    final elementIndex = _layout!.elements.indexWhere((e) => e.id == id);
    if (elementIndex <= 0) return;

    final element = _layout!.elements.removeAt(elementIndex);
    _layout!.elements.insert(elementIndex - 1, element);

    notifyListeners();
  }

  // Zoom methods
  void zoom(double factor) {
    // Get current scale from transformation matrix
    final currentScale = transformationController.value.getMaxScaleOnAxis();

    // Calculate target scale
    final targetScale = (currentScale * factor).clamp(0.1, 5.0);

    // Instead of using transformationController.view (which doesn't exist),
    // we'll use a different approach to get a focal point for zooming

    // Use the current BuildContext to get the layout's current size and position
    // For simplicity, zoom from the center of the viewport
    final focalPoint = Offset.zero; // Default focal point

    // Apply zoom with the focal point (which will be translated to the center of the viewport)
    zoomToPosition(targetScale: targetScale, focalPoint: focalPoint);

    // Update scale value for consistency
    _scale = targetScale;

    notifyListeners();
  }

  void resetZoom() {
    _scale = 1.0;
    transformationController.value = Matrix4.identity();
    notifyListeners();
  }

  void fitToScreen(BuildContext context) {
    if (_layout == null) return;

    // Get screen size
    final screenSize = MediaQuery.of(context).size;

    // Calculate available space (accounting for panels)
    final availableWidth =
        screenSize.width - 580; // Adjust based on sidebars width
    final availableHeight =
        screenSize.height - 160; // Adjust for top and bottom bars

    // Get layout dimensions
    final canvasWidth = _layout!.width.toDouble();
    final canvasHeight = _layout!.height.toDouble();

    // Calculate the scale needed to fit the canvas in the available space
    final scaleX = availableWidth / canvasWidth;
    final scaleY = availableHeight / canvasHeight;

    // Use the smaller scale to ensure entire canvas is visible
    final newScale =
        (scaleX < scaleY ? scaleX : scaleY) * 0.9; // 90% for margin

    // Ensure the scale is reasonable
    _scale = newScale.clamp(0.1, 3.0);

    // Calculate center of the canvas in user coordinates
    final centerX = canvasWidth / 2;
    final centerY = canvasHeight / 2;

    // Calculate center of the viewport in screen coordinates
    final viewportCenterX = availableWidth / 2;
    final viewportCenterY = availableHeight / 2;

    // Create a transformation that:
    // 1. Scales with the calculated scale
    // 2. Positions the canvas center at the viewport center
    final matrix =
        Matrix4.identity()
          ..scale(_scale)
          ..setTranslation(
            Vector3(
              viewportCenterX / _scale - centerX,
              viewportCenterY / _scale - centerY,
              0.0,
            ),
          );

    // Apply the transformation
    transformationController.value = matrix;

    notifyListeners();
  }

  void zoomToPosition({
    required double targetScale,
    required Offset focalPoint,
  }) {
    // Get the current transform
    final currentTransform = transformationController.value;

    // Get the current scale directly from the matrix for accuracy
    final currentScale = currentTransform.getMaxScaleOnAxis();

    // Calculate the point in scene coordinates before zooming
    final focalPointScene = transformationController.toScene(focalPoint);

    // Calculate the scale change
    final scaleChange = targetScale / currentScale;

    // Create a transformation matrix for this zoom operation
    final zoomMatrix =
        Matrix4.identity()
          ..translate(focalPointScene.dx, focalPointScene.dy)
          ..scale(scaleChange)
          ..translate(-focalPointScene.dx, -focalPointScene.dy);

    // Apply the zoom transformation to the current matrix
    final newMatrix = currentTransform * zoomMatrix;

    // Update the transform controller with the new matrix
    transformationController.value = newMatrix;

    // Update the scale value
    _scale = targetScale;

    notifyListeners();
  }

  void ensureCanvasVisible() {
    if (_layout == null) return;

    // Get the current matrix
    final matrix = transformationController.value;

    // Extract the translation and scale values
    final translationX = matrix.entry(0, 3);
    final translationY = matrix.entry(1, 3);
    final scale = matrix.getMaxScaleOnAxis();

    // Define more appropriate bounds based on scale
    final maxPanDistance =
        5000.0 / scale; // More relaxed boundaries for larger zoom levels

    // Check if canvas is too far out of view and adjust if needed
    bool needsRepositioning = false;
    double adjustedX = translationX;
    double adjustedY = translationY;

    // Use a smoother approach to limiting pan
    if (translationX.abs() > maxPanDistance) {
      // Apply a gradual correction instead of hard limit
      adjustedX = translationX * 0.9; // Move 90% back toward center
      needsRepositioning = true;
    }

    if (translationY.abs() > maxPanDistance) {
      adjustedY = translationY * 0.9; // Move 90% back toward center
      needsRepositioning = true;
    }

    // Apply corrected position if needed
    if (needsRepositioning) {
      // Use a clone to avoid modifying the original matrix
      final correctedMatrix =
          matrix.clone()
            ..setEntry(0, 3, adjustedX)
            ..setEntry(1, 3, adjustedY);

      // Update the controller with the corrected matrix
      transformationController.value = correctedMatrix;
    }
  }
}
