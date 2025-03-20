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

    element.x = dx;
    element.y = dy;

    if (_selectedElement?.id == id) {
      _selectedElement = element;
    }

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
    final scale = (scaleX < scaleY ? scaleX : scaleY) * 0.85; // 85% for margin

    // Ensure the scale is reasonable
    _scale = scale.clamp(0.1, 3.0);

    // Create a new transformation matrix
    final newMatrix = Matrix4.identity();

    // Apply scale
    newMatrix.scale(_scale, _scale, 1.0);

    // Calculate translation to center the canvas in the viewport
    final dx = (availableWidth - (canvasWidth * _scale)) / 2 / _scale;
    final dy = (availableHeight - (canvasHeight * _scale)) / 2 / _scale;

    // Apply translation
    newMatrix.translate(dx, dy);

    // Set the transformation
    transformationController.value = newMatrix;

    notifyListeners();
  }

  void zoomToPosition({
    required double targetScale,
    required Offset focalPoint,
  }) {
    // Get the current transform
    final currentTransform = transformationController.value;

    // Calculate the point before zooming
    final beforeOffset = transformationController.toScene(focalPoint);

    // Create a new transform with the new scale
    final newTransform = Matrix4.copy(currentTransform);

    // Get the current scale
    final currentScale = _scale;

    // Calculate scale change ratio
    final scaleChange = targetScale / currentScale;

    // Apply scaling
    newTransform.scale(scaleChange, scaleChange, 1.0);

    // Set the scale
    _scale = targetScale;

    // Apply the new transform to the controller
    transformationController.value = newTransform;

    // Calculate the point after zooming
    final afterOffset = transformationController.toScene(focalPoint);

    // Calculate the needed translation to keep the focal point stationary
    final translation = afterOffset - beforeOffset;

    // Apply the translation
    final correctedTransform = Matrix4.copy(newTransform)
      ..translate(-translation.dx, -translation.dy);

    // Set the final transform
    transformationController.value = correctedTransform;

    notifyListeners();
  }

  void ensureCanvasVisible() {
    if (_layout == null) return;

    // Get the current transform matrix
    final matrix = transformationController.value;

    // Extract the translation values
    final translationX = matrix.getTranslation().x;
    final translationY = matrix.getTranslation().y;

    // Define reasonable bounds for how far the canvas can be panned
    const maxPanDistance =
        1500.0; // Maximum distance canvas center can be from viewport center

    // Check if canvas is too far out of view and adjust if needed
    bool needsRepositioning = false;
    double adjustedX = translationX;
    double adjustedY = translationY;

    // Limit how far the canvas can be panned in each direction
    if (translationX.abs() > maxPanDistance) {
      adjustedX = translationX.sign * maxPanDistance;
      needsRepositioning = true;
    }

    if (translationY.abs() > maxPanDistance) {
      adjustedY = translationY.sign * maxPanDistance;
      needsRepositioning = true;
    }

    // Apply corrected position if needed
    if (needsRepositioning) {
      final correctedMatrix = Matrix4.copy(matrix);
      correctedMatrix.setTranslation(Vector3(adjustedX, adjustedY, 0));
      transformationController.value = correctedMatrix;
    }
  }
}
