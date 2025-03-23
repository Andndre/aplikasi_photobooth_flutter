import 'dart:math';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:vector_math/vector_math_64.dart';
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
  bool _snapToGrid = false; // Changed to false by default
  final _uuid = Uuid();

  // Add a TransformationController
  final TransformationController transformationController =
      TransformationController();

  // Add history tracking for undo/redo
  List<String> _history = [];
  int _historyIndex = -1;
  static const int _maxHistorySize = 50;
  bool _isUndoRedoOperation = false;

  // Getter for undo/redo state
  bool get canUndo => _historyIndex > 0;
  bool get canRedo => _historyIndex < _history.length - 1;

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

    // Reset history when loading a new layout
    _resetHistory();
    _saveToHistory(); // Save initial state

    notifyListeners();
  }

  // Method to save current state to history
  void _saveToHistory() {
    // Don't save if we're in the middle of an undo/redo operation
    if (_isUndoRedoOperation) return;
    if (_layout == null) return;

    // Convert current layout to JSON string
    final jsonString = jsonEncode(_layout!.toJson());

    // If we're not at the end of the history, truncate it
    if (_historyIndex < _history.length - 1) {
      _history = _history.sublist(0, _historyIndex + 1);
    }

    // Add current state to history
    _history.add(jsonString);
    _historyIndex = _history.length - 1;

    // Limit history size
    if (_history.length > _maxHistorySize) {
      _history.removeAt(0);
      _historyIndex--;
    }
  }

  // Reset history
  void _resetHistory() {
    _history = [];
    _historyIndex = -1;
  }

  // Implement undo
  bool undo() {
    if (!canUndo) return false;

    _isUndoRedoOperation = true;
    _historyIndex--;

    // Load the previous state
    final previousState = _history[_historyIndex];
    final previousLayout = Layouts.fromJson(jsonDecode(previousState));

    // Preserve selected element if possible
    final selectedId = _selectedElement?.id;

    _layout = previousLayout;

    // Try to reselect the previously selected element
    if (selectedId != null) {
      _selectedElement = _findElementById(selectedId);
    } else {
      _selectedElement = null;
    }

    _isUndoRedoOperation = false;
    notifyListeners();
    return true;
  }

  // Implement redo
  bool redo() {
    if (!canRedo) return false;

    _isUndoRedoOperation = true;
    _historyIndex++;

    // Load the next state
    final nextState = _history[_historyIndex];
    final nextLayout = Layouts.fromJson(jsonDecode(nextState));

    // Preserve selected element if possible
    final selectedId = _selectedElement?.id;

    _layout = nextLayout;

    // Try to reselect the previously selected element
    if (selectedId != null) {
      _selectedElement = _findElementById(selectedId);
    } else {
      _selectedElement = null;
    }

    _isUndoRedoOperation = false;
    notifyListeners();
    return true;
  }

  // Helper method to find an element by ID without casting null
  LayoutElement? _findElementById(String id) {
    if (_layout == null) return null;

    try {
      return _layout!.elements.firstWhere((e) => e.id == id);
    } catch (e) {
      // Element not found
      return null;
    }
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

    // Get image dimensions to calculate aspect ratio
    final imageBytes = file.readAsBytesSync();
    final decodedImage = decodeImageFromList(imageBytes);

    // Default image size with a reasonable maximum
    Size imageSize = const Size(200, 200);

    // Wait for image to load then update with proper dimensions
    decodedImage.then((image) {
      final aspectRatio = image.width / image.height;

      // If size is provided, use it as a starting point
      if (size != null) {
        imageSize = size;
      } else {
        // Calculate a size that preserves aspect ratio with max width/height of 300
        if (image.width > image.height) {
          // Landscape
          final maxWidth = 300.0;
          imageSize = Size(maxWidth, maxWidth / aspectRatio);
        } else {
          // Portrait
          final maxHeight = 300.0;
          imageSize = Size(maxHeight * aspectRatio, maxHeight);
        }
      }

      // Calculate position (centered if not provided)
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
        aspectRatioLocked: true, // Default to true
      );

      _layout!.elements.add(newElement);
      _selectedElement = newElement;

      // Save state for undo/redo
      _saveToHistory();

      notifyListeners();
    });
  }

  void addTextElement({String? text, Offset? position, Size? size}) {
    if (_layout == null) return;

    // Enforce minimum size
    final textSize = size ?? const Size(200, 50);
    final safeWidth = max(50.0, textSize.width);
    final safeHeight = max(30.0, textSize.height);

    // Ensure the element is placed within the layout bounds
    final pos =
        position ??
        Offset(
          (_layout!.width / 2) - (safeWidth / 2),
          (_layout!.height / 2) - (safeHeight / 2),
        );

    // Ensure position is within bounds
    final safeX = pos.dx.clamp(0.0, _layout!.width - safeWidth);
    final safeY = pos.dy.clamp(0.0, _layout!.height - safeHeight);

    // Create text element with transparent background and topLeft alignment by default
    final newElement = TextElement(
      id: _uuid.v4(),
      x: safeX,
      y: safeY,
      width: safeWidth,
      height: safeHeight,
      text: text ?? 'New Text',
      fontFamily: 'Arial',
      fontSize: 20.0,
      color: '#000000',
      backgroundColor: 'transparent', // Use 'transparent' instead of '#FFFFFF'
      isBold: false,
      isItalic: false,
      alignment: 'topLeft', // Changed from 'center' to 'topLeft'
      rotation: 0.0,
    );

    try {
      _layout!.elements.add(newElement);
      _selectedElement = newElement;

      // Save state for undo/redo
      _saveToHistory();

      notifyListeners();
    } catch (e) {
      print('Error adding text element: $e');
    }
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

    // Save state for undo/redo
    _saveToHistory();

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

    // Save state for undo/redo
    _saveToHistory();

    // Explicitly notify listeners to ensure UI updates
    notifyListeners();
  }

  void updateElementSize(String id, Size size) {
    if (_layout == null) return;

    final elementIndex = _layout!.elements.indexWhere((e) => e.id == id);
    if (elementIndex < 0) return;

    final element = _layout!.elements[elementIndex];

    // Handle aspect ratio for image elements
    if (element.type == 'image') {
      final imageElement = element as ImageElement;

      // If aspect ratio is locked, calculate new height based on width
      if (imageElement.aspectRatioLocked) {
        final aspectRatio = element.width / element.height;

        // Determine if width or height was changed by comparing with original values
        final widthChanged = size.width != element.width;

        if (widthChanged) {
          // Adjust height based on width change
          size = Size(size.width, size.width / aspectRatio);
        } else {
          // Adjust width based on height change
          size = Size(size.height * aspectRatio, size.height);
        }
      }
    }

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

    // Save state for undo/redo
    _saveToHistory();

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

    // Save state for undo/redo
    _saveToHistory();

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

    // Handle "transparent" specifically for background
    if (backgroundColor != null) {
      // If color is actually the string "transparent", preserve that
      if (backgroundColor == "transparent" ||
          backgroundColor.toLowerCase() == "transparent") {
        element.backgroundColor = "transparent";
      }
      // Otherwise use the hex value, keeping alpha if present
      else {
        element.backgroundColor = backgroundColor;
      }
    }

    if (isBold != null) element.isBold = isBold;
    if (isItalic != null) element.isItalic = isItalic;
    if (alignment != null) element.alignment = alignment;

    if (_selectedElement?.id == id) {
      _selectedElement = element;
    }

    // Save state for undo/redo
    _saveToHistory();

    notifyListeners();
  }

  void updateImageElement(
    String id, {
    String? path,
    double? opacity,
    bool? aspectRatioLocked,
  }) {
    if (_layout == null) return;

    final elementIndex = _layout!.elements.indexWhere((e) => e.id == id);
    if (elementIndex < 0 || _layout!.elements[elementIndex].type != 'image')
      return;

    final element = _layout!.elements[elementIndex] as ImageElement;

    if (path != null) {
      element.path = path;

      // If new image is loaded, update aspect ratio
      if (aspectRatioLocked ?? element.aspectRatioLocked) {
        final file = File(path);
        if (file.existsSync()) {
          final imageBytes = file.readAsBytesSync();
          final decodedImage = decodeImageFromList(imageBytes);

          decodedImage.then((image) {
            final aspectRatio = image.width / image.height;

            // Maintain current width, adjust height to match aspect ratio
            final newHeight = element.width / aspectRatio;
            element.height = newHeight;

            if (_selectedElement?.id == id) {
              _selectedElement = element;
            }

            notifyListeners();
          });
        }
      }
    }

    if (opacity != null) element.opacity = opacity;
    if (aspectRatioLocked != null)
      element.aspectRatioLocked = aspectRatioLocked;

    if (_selectedElement?.id == id) {
      _selectedElement = element;
    }

    // Save state for undo/redo
    _saveToHistory();

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

    // Save state for undo/redo
    _saveToHistory();

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

    // Save state for undo/redo
    _saveToHistory();

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

    // Save state for undo/redo
    _saveToHistory();

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

    // Save state for undo/redo
    _saveToHistory();

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

    // Save state for undo/redo
    _saveToHistory();

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

    // Save state for undo/redo
    _saveToHistory();

    // Force notification to all listeners
    notifyListeners();
  }

  void bringToFront(String id) {
    if (_layout == null) return;

    final elementIndex = _layout!.elements.indexWhere((e) => e.id == id);
    if (elementIndex < 0) return;

    final element = _layout!.elements.removeAt(elementIndex);
    _layout!.elements.add(element);

    // Save state for undo/redo
    _saveToHistory();

    notifyListeners();
  }

  void sendToBack(String id) {
    if (_layout == null) return;

    final elementIndex = _layout!.elements.indexWhere((e) => e.id == id);
    if (elementIndex < 0) return;

    final element = _layout!.elements.removeAt(elementIndex);
    _layout!.elements.insert(0, element);

    // Save state for undo/redo
    _saveToHistory();

    notifyListeners();
  }

  void moveForward(String id) {
    if (_layout == null) return;

    final elementIndex = _layout!.elements.indexWhere((e) => e.id == id);
    if (elementIndex < 0 || elementIndex >= _layout!.elements.length - 1)
      return;

    final element = _layout!.elements.removeAt(elementIndex);
    _layout!.elements.insert(elementIndex + 1, element);

    // Save state for undo/redo
    _saveToHistory();

    notifyListeners();
  }

  void moveBackward(String id) {
    if (_layout == null) return;

    final elementIndex = _layout!.elements.indexWhere((e) => e.id == id);
    if (elementIndex <= 0) return;

    final element = _layout!.elements.removeAt(elementIndex);
    _layout!.elements.insert(elementIndex - 1, element);

    // Save state for undo/redo
    _saveToHistory();

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

  void reorderElements(int oldIndex, int newIndex) {
    if (_layout == null) return;

    if (oldIndex < 0 ||
        oldIndex >= _layout!.elements.length ||
        newIndex < 0 ||
        newIndex >= _layout!.elements.length) {
      return; // Invalid indices
    }

    // Remove the element from the old position
    final element = _layout!.elements.removeAt(oldIndex);

    // Insert it at the new position
    _layout!.elements.insert(newIndex, element);

    // Save state for undo/redo
    _saveToHistory();

    notifyListeners();
  }

  void toggleAllElementsVisibility() {
    if (_layout == null || _layout!.elements.isEmpty) return;

    // Determine the new state based on majority of current states
    // If more elements are visible, we'll hide all; otherwise, show all
    final visibleCount = _layout!.elements.where((e) => e.isVisible).length;
    final shouldHide = visibleCount > _layout!.elements.length / 2;

    // Apply the new visibility state to all elements
    for (final element in _layout!.elements) {
      element.isVisible = !shouldHide;
    }

    notifyListeners();
  }

  void toggleAllElementsLock() {
    if (_layout == null || _layout!.elements.isEmpty) return;

    // Similar to visibility toggle - check majority state
    final lockedCount = _layout!.elements.where((e) => e.isLocked).length;
    final shouldUnlock = lockedCount > _layout!.elements.length / 2;

    // Apply the new lock state to all elements
    for (final element in _layout!.elements) {
      element.isLocked = !shouldUnlock;
    }

    notifyListeners();
  }
}
