import 'dart:math';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photobooth/models/layout_model.dart';
import 'package:photobooth/models/renderables/camera_element.dart';
import 'package:photobooth/models/renderables/fonts.dart';
import 'package:photobooth/models/renderables/image_element.dart';
import 'package:photobooth/models/renderables/layout_element.dart';
import 'package:photobooth/models/renderables/text_element.dart';
import 'package:photobooth/providers/layout_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:vector_math/vector_math_64.dart' as vector_math;
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';

enum EditMode { select, move, text, image, camera }

class LayoutEditorProvider extends ChangeNotifier {
  LayoutModel? layout;
  LayoutElement? selectedElement;

  final Set<String> selectedElementIds = {};

  EditMode editMode = EditMode.select;

  List<LayoutElement> clipboard = [];

  bool hasUnsavedChanges = false;

  double scale = 1.0;
  Offset offset = Offset.zero;

  bool isDragging = false;
  bool isResizing = false;
  bool showGrid = true;
  bool snapToGrid = false; // Changed to false by default
  final uuid = Uuid();

  final TransformationController transformationController =
      TransformationController();

  // Add history tracking for undo/redo
  List<String> history = [];
  int historyIndex = -1;
  // TODO: Add this to settings
  static const int maxHistorySize = 50;
  bool isUndoRedoOperation = false;

  // Track expanded state of groups
  final Set<String> expandedGroupIds = {};

  // Undo/redo state
  bool get canUndo => historyIndex > 0;
  bool get canRedo => historyIndex < history.length - 1;

  bool get hasMultipleElementsSelected => selectedElementIds.length > 1;

  bool fontPathsLoaded = false;
  bool isLoadingFonts = false;
  Map<String, String> fontPaths = {};

  // Set to store loaded fonts to avoid duplicate loading
  final Set<String> loadedFonts = {};
  bool initialFontLoadComplete = false;

  List<LayoutElement> get selectedElements {
    if (layout == null) return [];
    return layout!.elements
        .where((element) => selectedElementIds.contains(element.id))
        .toList();
  }

  void setLayout(LayoutModel newLayout) {
    layout = LayoutModel.fromJson(newLayout.toJson());
    history = [];
    selectedElement = null;
    selectedElementIds.clear();
    hasUnsavedChanges = false;
    preloadFonts();
    notifyListeners();
  }

  void saveToHistory() {
    // Don't save if we're in the middle of an undo/redo operation
    if (isUndoRedoOperation) return;
    if (layout == null) return;

    // Convert current layout to JSON string
    final jsonString = jsonEncode(layout!.toJson());

    // If we're not at the end of the history, truncate it
    if (historyIndex < history.length - 1) {
      history = history.sublist(0, historyIndex + 1);
    }

    // Add current state to history
    history.add(jsonString);
    historyIndex = history.length - 1;

    // Limit history size
    if (history.length > maxHistorySize) {
      history.removeAt(0);
      historyIndex--;
    }

    hasUnsavedChanges = true;
    notifyListeners();
  }

  void resetHistory() {
    history = [];
    historyIndex = -1;
  }

  bool undo() {
    if (!canUndo) return false;

    isUndoRedoOperation = true;
    historyIndex--;

    // Load the previous state
    final previousState = history[historyIndex];
    final previousLayout = LayoutModel.fromJson(jsonDecode(previousState));

    // Preserve selected element if possible
    final selectedId = selectedElement?.id;

    layout = previousLayout;

    // Try to reselect the previously selected element
    if (selectedId != null) {
      selectedElement = layout?.getElementById(selectedId);
    } else {
      selectedElement = null;
    }

    isUndoRedoOperation = false;
    notifyListeners();
    return true;
  }

  bool redo() {
    if (!canRedo) return false;

    isUndoRedoOperation = true;
    historyIndex++;

    // Load the next state
    final nextState = history[historyIndex];
    final nextLayout = LayoutModel.fromJson(jsonDecode(nextState));

    // Preserve selected element if possible
    final selectedId = selectedElement?.id;

    layout = nextLayout;

    // Try to reselect the previously selected element
    if (selectedId != null) {
      selectedElement = layout?.getElementById(selectedId);
    } else {
      selectedElement = null;
    }

    isUndoRedoOperation = false;
    notifyListeners();
    return true;
  }

  void setEditMode(EditMode mode) {
    editMode = mode;
    notifyListeners();
  }

  void selectElement(LayoutElement? element, {bool addToSelection = false}) {
    if (element == null) {
      selectedElement = null;
      selectedElementIds.clear();
      notifyListeners();
      return;
    }

    if (addToSelection) {
      // Check if Shift key is being pressed for range selection
      final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

      if (isShiftPressed && selectedElement != null && layout != null) {
        if (selectedElementIds.contains(element.id)) {
          selectedElementIds.remove(element.id);
          // If this was the primary selected element, update it
          if (selectedElement?.id == element.id) {
            selectedElement =
                selectedElementIds.isNotEmpty
                    ? layout?.getElementById(selectedElementIds.first)
                    : null;
          }
        } else {
          selectedElement = element;
          selectedElementIds.add(element.id);
        }
      } else {
        selectedElement = element;
        selectedElementIds.clear();
        selectedElementIds.add(element.id);
      }
    } else {
      selectedElement = element;
      selectedElementIds.clear();
      selectedElementIds.add(element.id);
    }

    notifyListeners();
  }

  bool isElementSelected(String elementId) {
    return selectedElementIds.contains(elementId);
  }

  void selectElements(List<LayoutElement> elements) {
    if (elements.isEmpty) {
      selectElement(null);
      return;
    }

    selectedElementIds.clear();
    for (final element in elements) {
      selectedElementIds.add(element.id);
    }

    // Set the first element as the primary selected element
    selectedElement = elements.first;

    notifyListeners();
  }

  void selectAllElements() {
    if (layout == null || layout!.elements.isEmpty) return;

    selectedElementIds.clear();
    for (final element in layout!.elements) {
      selectedElementIds.add(element.id);
    }

    // Set the first element as the primary selected element
    selectedElement = layout!.elements.first;

    notifyListeners();
  }

  void alignElementsHorizontally(String alignment) {
    if (layout == null || selectedElements.length <= 1) return;

    // Calculate bounds
    double minX = double.infinity;
    double maxX = -double.infinity;

    for (final element in selectedElements) {
      minX = min(minX, element.x);
      maxX = max(maxX, element.x + element.width);
    }

    saveToHistory();

    double width = maxX - minX;

    // Apply alignment
    for (final element in selectedElements) {
      double newX;

      switch (alignment) {
        case 'start':
          newX = minX;
          break;
        case 'center':
          newX = minX + (width - element.width) / 2;
          break;
        case 'end':
          newX = maxX - element.width;
          break;
        case 'distribute':
          // Implement distribute logic if needed
          continue;
        default:
          continue;
      }

      updateElementPosition(element.id, Offset(newX, element.y));
    }

    // Save ending state for undo
    saveToHistory();
  }

  void alignElementsVertically(String alignment) {
    if (layout == null || selectedElements.length <= 1) return;

    // Calculate bounds
    double minY = double.infinity;
    double maxY = -double.infinity;

    for (final element in selectedElements) {
      minY = min(minY, element.y);
      maxY = max(maxY, element.y + element.height);
    }

    double height = maxY - minY;

    // Save starting state for undo
    saveToHistory();

    // Apply alignment
    for (final element in selectedElements) {
      double newY;

      switch (alignment) {
        case 'start':
          newY = minY;
          break;
        case 'center':
          newY = minY + (height - element.height) / 2;
          break;
        case 'end':
          newY = maxY - element.height;
          break;
        case 'distribute':
          // Implement distribute logic if needed
          continue;
        default:
          continue;
      }

      updateElementPosition(element.id, Offset(element.x, newY));
    }

    // Save ending state for undo
    saveToHistory();
  }

  void distributeElementsHorizontally() {
    if (layout == null || selectedElements.length < 3) return;

    // Save starting state for undo
    saveToHistory();

    // Sort elements by x position
    final elements = [...selectedElements];
    elements.sort((a, b) => a.x.compareTo(b.x));

    // Calculate total available space
    final leftmost = elements.first.x;
    final rightmost = elements.last.x + elements.last.width;
    final totalWidth = rightmost - leftmost;

    // Calculate element widths sum
    double elementsWidth = 0;
    for (final element in elements) {
      elementsWidth += element.width;
    }

    // Calculate the gap between elements
    final gap = (totalWidth - elementsWidth) / (elements.length - 1);

    // Apply distribution
    double currentX = leftmost;
    for (int i = 0; i < elements.length; i++) {
      final element = elements[i];

      // Skip the first element as it stays in place
      if (i > 0) {
        updateElementPosition(element.id, Offset(currentX, element.y));
      }

      // Move to next position
      currentX += element.width + gap;
    }

    // Save ending state for undo
    saveToHistory();
  }

  void distributeElementsVertically() {
    if (layout == null || selectedElements.length < 3) return;

    // Save starting state for undo
    saveToHistory();

    // Sort elements by y position
    final elements = [...selectedElements];
    elements.sort((a, b) => a.y.compareTo(b.y));

    // Calculate total available space
    final topmost = elements.first.y;
    final bottommost = elements.last.y + elements.last.height;
    final totalHeight = bottommost - topmost;

    // Calculate element heights sum
    double elementsHeight = 0;
    for (final element in elements) {
      elementsHeight += element.height;
    }

    // Calculate the gap between elements
    final gap = (totalHeight - elementsHeight) / (elements.length - 1);

    // Apply distribution
    double currentY = topmost;
    for (int i = 0; i < elements.length; i++) {
      final element = elements[i];

      // Skip the first element as it stays in place
      if (i > 0) {
        updateElementPosition(element.id, Offset(element.x, currentY));
      }

      // Move to next position
      currentY += element.height + gap;
    }

    // Save ending state for undo
    saveToHistory();
  }

  // Add method to delete multiple elements
  void deleteSelectedElements() {
    if (layout == null || selectedElementIds.isEmpty) return;

    // Save state for undo
    saveToHistory();

    // Make a copy to avoid modifying during iteration
    final selectedIds = {...selectedElementIds};

    for (final id in selectedIds) {
      final elementIndex = layout!.elements.indexWhere((e) => e.id == id);
      if (elementIndex >= 0) {
        layout!.elements.removeAt(elementIndex);
      }
    }

    // Clear selection
    selectedElement = null;
    selectedElementIds.clear();

    notifyListeners();
  }

  void toggleGrid() {
    showGrid = !showGrid;
    notifyListeners();
  }

  void toggleSnapToGrid() {
    snapToGrid = !snapToGrid;
    notifyListeners();
  }

  void startDrag() {
    isDragging = true;
    notifyListeners();
  }

  void stopDrag() {
    isDragging = false;
    notifyListeners();
  }

  void startResize() {
    isResizing = true;
    notifyListeners();
  }

  void stopResize() {
    isResizing = false;
    notifyListeners();
  }

  void setScale(double newScale) {
    scale = newScale.clamp(0.1, 1.0);
    notifyListeners();
  }

  void setOffset(Offset newOffset) {
    offset = newOffset;
    notifyListeners();
  }

  void addImageElement(String path, {Offset? position, Size? size}) {
    if (layout == null) return;

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
            (layout!.width / 2) - (imageSize.width / 2),
            (layout!.height / 2) - (imageSize.height / 2),
          );

      final newElement = ImageElement(
        id: uuid.v4(),
        x: pos.dx,
        y: pos.dy,
        width: imageSize.width,
        height: imageSize.height,
        path: path,
        aspectRatioLocked: true, // Default to true
      );

      layout!.elements.add(newElement);
      selectedElement = newElement;

      // Save state for undo/redo
      saveToHistory();

      notifyListeners();
    });
  }

  Future<void> preloadFonts() async {
    if (layout == null) return;
    await Fonts.loadUsedFonts(layout: layout!);
  }

  // Override addTextElement to also preload font
  void addTextElement({String? text, Offset? position, Size? size}) {
    if (layout == null) return;

    // Enforce minimum size
    final textSize = size ?? const Size(200, 50);
    final safeWidth = max(50.0, textSize.width);
    final safeHeight = max(30.0, textSize.height);

    // Ensure the element is placed within the layout bounds
    final pos =
        position ??
        Offset(
          (layout!.width / 2) - (safeWidth / 2),
          (layout!.height / 2) - (safeHeight / 2),
        );

    // Ensure position is within bounds
    final safeX = pos.dx.clamp(0.0, layout!.width - safeWidth);
    final safeY = pos.dy.clamp(0.0, layout!.height - safeHeight);

    // Create text element with transparent background and topLeft alignment by default
    final newElement = TextElement(
      id: uuid.v4(),
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
      layout!.elements.add(newElement);
      selectedElement = newElement;

      // Preload font if needed (most system fonts should already be loaded)
      Fonts.preloadFont(newElement.fontFamily, newElement.isGoogleFont);

      // Save state for undo/redo
      saveToHistory();

      notifyListeners();
    } catch (e) {
      print('Error adding text element: $e');
    }
  }

  void addCameraElement({Offset? position, Size? size}) {
    if (layout == null) return;

    final cameraSize = size ?? const Size(300, 300);
    final pos =
        position ??
        Offset(
          (layout!.width / 2) - (cameraSize.width / 2),
          (layout!.height / 2) - (cameraSize.height / 2),
        );

    // Count existing camera elements for label
    final cameraCount =
        layout!.elements.where((e) => e.type == 'camera').length;

    final newElement = CameraElement(
      id: uuid.v4(),
      x: pos.dx,
      y: pos.dy,
      width: cameraSize.width,
      height: cameraSize.height,
      label: 'Photo Spot ${cameraCount + 1}',
    );

    layout!.elements.add(newElement);
    selectedElement = newElement;

    // Save state for undo/redo
    saveToHistory();

    notifyListeners();
  }

  void updateElementPosition(String id, Offset position) {
    if (layout == null) return;

    final elementIndex = layout!.elements.indexWhere((e) => e.id == id);
    if (elementIndex < 0) return;

    final element = layout!.elements[elementIndex];

    // Ensure element isn't locked
    if (element.isLocked) return;

    // Apply snapping if enabled
    double newX = position.dx;
    double newY = position.dy;

    if (snapToGrid) {
      const gridSize = 10.0;
      newX = (newX / gridSize).round() * gridSize;
      newY = (newY / gridSize).round() * gridSize;
    }

    // Update element position
    element.x = newX;
    element.y = newY;

    // Update selected element reference if needed
    if (selectedElement?.id == id) {
      selectedElement = element;
    }

    // Mark that we have unsaved changes
    hasUnsavedChanges = true;

    // Explicitly notify listeners to ensure UI updates
    notifyListeners();
  }

  // Also update the resizing method to handle groups
  void updateElementSize(String id, Size size) {
    if (layout == null) return;

    final elementIndex = layout!.elements.indexWhere((e) => e.id == id);
    if (elementIndex < 0) return;

    final element = layout!.elements[elementIndex];

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

    if (snapToGrid) {
      const gridSize = 10.0;
      width = (width / gridSize).round() * gridSize;
      height = (height / gridSize).round() * gridSize;
    }

    // Ensure minimum size
    width = width.clamp(10.0, double.infinity);
    height = height.clamp(10.0, double.infinity);

    // Update element dimensions
    element.width = width;
    element.height = height;

    if (selectedElement?.id == id) {
      selectedElement = element;
    }

    // Mark that we have unsaved changes
    hasUnsavedChanges = true;

    notifyListeners();
  }

  void updateElementRotation(String id, double rotation) {
    if (layout == null) return;

    final elementIndex = layout!.elements.indexWhere((e) => e.id == id);
    if (elementIndex < 0) return;

    final element = layout!.elements[elementIndex];
    element.rotation = rotation;

    if (selectedElement?.id == id) {
      selectedElement = element;
    }

    // Save state for undo/redo
    saveToHistory();

    notifyListeners();
  }

  // Override updateTextElement to also preload fonts when font is changed
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
    bool? isGoogleFont, // New parameter
  }) {
    if (layout == null) return;

    final elementIndex = layout!.elements.indexWhere((e) => e.id == id);
    if (elementIndex < 0 || layout!.elements[elementIndex].type != 'text') {
      return;
    }

    final element = layout!.elements[elementIndex] as TextElement;

    // Preload new font if fontFamily is changing
    if (fontFamily != null && fontFamily != element.fontFamily) {
      final isGoogle = isGoogleFont ?? element.isGoogleFont;
      Fonts.preloadFont(fontFamily, isGoogle);
    }

    if (text != null) element.text = text;
    if (fontFamily != null) {
      element.fontFamily = fontFamily;

      // Auto-detect if this is a Google Font
      if (isGoogleFont == null) {
        // Check if font exists in Google Fonts registry
        try {
          final isAvailableInGoogleFonts = GoogleFonts.asMap().containsKey(
            fontFamily,
          );
          element.isGoogleFont = isAvailableInGoogleFonts;
        } catch (e) {
          // If there's an error checking, assume it's not a Google Font
          element.isGoogleFont = false;
        }
      } else {
        element.isGoogleFont = isGoogleFont;
      }
    }
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
    if (isGoogleFont != null) element.isGoogleFont = isGoogleFont;

    if (selectedElement?.id == id) {
      selectedElement = element;
    }

    // Save state for undo/redo
    saveToHistory();

    notifyListeners();
  }

  void updateImageElement(
    String id, {
    String? path,
    double? opacity,
    bool? aspectRatioLocked,
  }) {
    if (layout == null) return;

    final elementIndex = layout!.elements.indexWhere((e) => e.id == id);
    if (elementIndex < 0 || layout!.elements[elementIndex].type != 'image') {
      return;
    }

    final element = layout!.elements[elementIndex] as ImageElement;

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

            if (selectedElement?.id == id) {
              selectedElement = element;
            }

            notifyListeners();
          });
        }
      }
    }

    if (opacity != null) element.opacity = opacity;
    if (aspectRatioLocked != null) {
      element.aspectRatioLocked = aspectRatioLocked;
    }

    if (selectedElement?.id == id) {
      selectedElement = element;
    }

    // Save state for undo/redo
    saveToHistory();

    notifyListeners();
  }

  void updateCameraElement(String id, {String? label}) {
    if (layout == null) return;

    final elementIndex = layout!.elements.indexWhere((e) => e.id == id);
    if (elementIndex < 0 || layout!.elements[elementIndex].type != 'camera') {
      return;
    }

    final element = layout!.elements[elementIndex] as CameraElement;

    if (label != null) element.label = label;

    if (selectedElement?.id == id) {
      selectedElement = element;
    }

    // Save state for undo/redo
    saveToHistory();

    notifyListeners();
  }

  void toggleElementLock(String id) {
    if (layout == null) return;

    final elementIndex = layout!.elements.indexWhere((e) => e.id == id);
    if (elementIndex < 0) return;

    final element = layout!.elements[elementIndex];
    element.isLocked = !element.isLocked;

    if (selectedElement?.id == id) {
      selectedElement = element;
    }

    // Save state for undo/redo
    saveToHistory();

    notifyListeners();
  }

  void toggleElementVisibility(String id) {
    if (layout == null) return;

    final elementIndex = layout!.elements.indexWhere((e) => e.id == id);
    if (elementIndex < 0) return;

    final element = layout!.elements[elementIndex];
    element.isVisible = !element.isVisible;

    if (selectedElement?.id == id) {
      selectedElement = element;
    }

    // Save state for undo/redo
    saveToHistory();

    notifyListeners();
  }

  void deleteElement(String id) {
    if (layout == null) return;

    final elementIndex = layout!.elements.indexWhere((e) => e.id == id);
    if (elementIndex < 0) return;

    layout!.elements.removeAt(elementIndex);

    if (selectedElement?.id == id) {
      selectedElement = null;
    }

    // Save state for undo/redo
    saveToHistory();

    notifyListeners();
  }

  void copyElement(String id) {
    if (layout == null) return;

    final element = layout!.elements.firstWhere(
      (e) => e.id == id,
      orElse: () => throw Exception('Element not found'),
    );

    clipboard = [element];
    notifyListeners();
  }

  void pasteElement() {
    if (layout == null || clipboard.isEmpty) return;

    for (final sourceElement in clipboard) {
      late LayoutElement newElement;

      switch (sourceElement.type) {
        case 'image':
          final source = sourceElement as ImageElement;
          newElement = ImageElement(
            id: uuid.v4(),
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
            id: uuid.v4(),
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
              layout!.elements.where((e) => e.type == 'camera').length;
          newElement = CameraElement(
            id: uuid.v4(),
            x: source.x + 20,
            y: source.y + 20,
            width: source.width,
            height: source.height,
            label: 'Photo Spot ${cameraCount + 1}',
            rotation: source.rotation,
          );
          break;
      }

      layout!.elements.add(newElement);
      selectedElement = newElement;
    }

    // Save state for undo/redo
    saveToHistory();

    notifyListeners();
  }

  void updateLayoutBackground(String color) {
    if (layout == null) return;

    print("Updating background color to: $color");

    // Ensure color is properly formatted
    if (!color.startsWith('#')) {
      color = '#$color';
    }

    // Update layout background
    layout!.backgroundColor = color;

    // Save state for undo/redo
    saveToHistory();

    // Force notification to all listeners
    notifyListeners();
  }

  void bringToFront(String id) {
    if (layout == null) return;

    final elementIndex = layout!.elements.indexWhere((e) => e.id == id);
    if (elementIndex < 0) return;

    final element = layout!.elements.removeAt(elementIndex);
    layout!.elements.add(element);

    // Save state for undo/redo
    saveToHistory();

    notifyListeners();
  }

  void sendToBack(String id) {
    if (layout == null) return;

    final elementIndex = layout!.elements.indexWhere((e) => e.id == id);
    if (elementIndex < 0) return;

    final element = layout!.elements.removeAt(elementIndex);
    layout!.elements.insert(0, element);

    // Save state for undo/redo
    saveToHistory();

    notifyListeners();
  }

  void moveForward(String id) {
    if (layout == null) return;

    final elementIndex = layout!.elements.indexWhere((e) => e.id == id);
    if (elementIndex < 0 || elementIndex >= layout!.elements.length - 1) {
      return;
    }

    final element = layout!.elements.removeAt(elementIndex);
    layout!.elements.insert(elementIndex + 1, element);

    // Save state for undo/redo
    saveToHistory();

    notifyListeners();
  }

  void moveBackward(String id) {
    if (layout == null) return;

    final elementIndex = layout!.elements.indexWhere((e) => e.id == id);
    if (elementIndex <= 0) return;

    final element = layout!.elements.removeAt(elementIndex);
    layout!.elements.insert(elementIndex - 1, element);

    // Save state for undo/redo
    saveToHistory();

    notifyListeners();
  }

  // Zoom methods
  void zoom(double factor) {
    // Get current scale from transformation matrix
    final currentScale = transformationController.value.getMaxScaleOnAxis();

    // Calculate target scale
    final targetScale = (currentScale * factor).clamp(
      0.1,
      1.0,
    ); // Changed from 5.0 to 1.0

    // Instead of using transformationController.view (which doesn't exist),
    // we'll use a different approach to get a focal point for zooming

    // Use the current BuildContext to get the layout's current size and position
    // For simplicity, zoom from the center of the viewport
    final focalPoint = Offset.zero; // Default focal point

    // Apply zoom with the focal point (which will be translated to the center of the viewport)
    zoomToPosition(targetScale: targetScale, focalPoint: focalPoint);

    // Update scale value for consistency
    scale = targetScale;

    notifyListeners();
  }

  void resetZoom() {
    scale = 1.0;
    transformationController.value = Matrix4.identity();
    notifyListeners();
  }

  void fitToScreen(BuildContext context) {
    if (layout == null) return;

    // Get screen size
    final screenSize = MediaQuery.of(context).size;

    // Calculate available space (accounting for panels)
    final availableWidth =
        screenSize.width - 580; // Adjust based on sidebars width
    final availableHeight =
        screenSize.height - 160; // Adjust for top and bottom bars

    // Get layout dimensions
    final canvasWidth = layout!.width.toDouble();
    final canvasHeight = layout!.height.toDouble();

    // Calculate the scale needed to fit the canvas in the available space
    final scaleX = availableWidth / canvasWidth;
    final scaleY = availableHeight / canvasHeight;

    // Use the smaller scale to ensure entire canvas is visible
    final newScale =
        (scaleX < scaleY ? scaleX : scaleY) * 0.9; // 90% for margin

    // Ensure the scale is reasonable
    scale = newScale.clamp(0.1, 3.0);

    // Calculate center of the canvas in user coordinates
    final centerX = canvasWidth / 2;
    final centerY = canvasHeight / 2;

    // Calculate center of the viewport in screen coordinates
    final viewportCenterX = availableWidth / scale;
    final viewportCenterY = availableHeight / scale;

    // Create a transformation that:
    // 1. Scales with the calculated scale
    // 2. Positions the canvas center at the viewport center
    final matrix =
        Matrix4.identity()
          ..scale(scale)
          ..setTranslation(
            vector_math.Vector3(
              viewportCenterX / scale - centerX,
              viewportCenterY / scale - centerY,
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

    // Calculate the scale change (ensure we don't exceed 1.0)
    final scaleChange = (targetScale / currentScale).clamp(
      0.1,
      1.0 / currentScale,
    );

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
    scale = targetScale;

    notifyListeners();
  }

  void ensureCanvasVisible() {
    if (layout == null) return;

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
    if (layout == null) return;

    if (oldIndex < 0 ||
        oldIndex >= layout!.elements.length ||
        newIndex < 0 ||
        newIndex >= layout!.elements.length) {
      return; // Invalid indices
    }

    // Remove the element from the old position
    final element = layout!.elements.removeAt(oldIndex);

    // Insert it at the new position
    layout!.elements.insert(newIndex, element);

    // Save state for undo/redo
    saveToHistory();

    notifyListeners();
  }

  void toggleAllElementsVisibility() {
    if (layout == null || layout!.elements.isEmpty) return;

    // Determine the new state based on majority of current states
    // If more elements are visible, we'll hide all; otherwise, show all
    final visibleCount = layout!.elements.where((e) => e.isVisible).length;
    final shouldHide = visibleCount > layout!.elements.length / 2;

    // Apply the new visibility state to all elements
    for (final element in layout!.elements) {
      element.isVisible = !shouldHide;
    }

    notifyListeners();
  }

  void toggleAllElementsLock() {
    if (layout == null || layout!.elements.isEmpty) return;

    // Similar to visibility toggle - check majority state
    final lockedCount = layout!.elements.where((e) => e.isLocked).length;
    final shouldUnlock = lockedCount > layout!.elements.length / 2;

    // Apply the new lock state to all elements
    for (final element in layout!.elements) {
      element.isLocked = !shouldUnlock;
    }

    saveToHistory();

    notifyListeners();
  }

  // Helper to check if selected element is a group
  bool get isSelectedElementGroup =>
      selectedElement != null && selectedElement!.type == 'group';

  // Method to save the current layout state - to be called from the editor screen
  void saveLayout(BuildContext context, int layoutIndex) async {
    // Don't attempt to save if no layout is loaded
    if (layout == null) return;

    // Set the save operation flag - this method doesn't actually perform the save
    // It merely marks the current state as the "saved" state for the editor to handle
    final layoutsProvider = Provider.of<LayoutsProvider>(
      context,
      listen: false,
    );

    await layoutsProvider.editLayout(layoutIndex, layout!);

    if (context.mounted) {
      // Mark changes as saved
      hasUnsavedChanges = false;
    }

    // Notify listeners about the save request
    notifyListeners();
  }

  void centerElementInCanvas(String elementId, bool horizontal, bool vertical) {
    final element = getElementById(elementId);
    if (element == null) return;

    final canvasWidth = layout!.width.toDouble();
    final canvasHeight = layout!.height.toDouble();

    double newX = element.x;
    double newY = element.y;

    if (horizontal) {
      newX = (canvasWidth - element.width) / 2;
    }

    if (vertical) {
      newY = (canvasHeight - element.height) / 2;
    }

    updateElementPosition(elementId, Offset(newX, newY));

    // Mark that we have unsaved changes (already set in updateElementPosition)
    // and save to history
    saveToHistory();
  }

  // Add getElementById method
  LayoutElement? getElementById(String id) {
    if (layout == null) return null;
    try {
      return layout!.elements.firstWhere((element) => element.id == id);
    } catch (e) {
      return null;
    }
  }
}
