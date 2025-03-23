import 'package:aplikasi_photobooth_flutter/providers/layout_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import '../../models/layouts.dart';

// Common widgets
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Divider(),
        ],
      ),
    );
  }
}

class _NumberPropertyRow extends StatelessWidget {
  final String label;
  final double value;
  final Function(double) onChanged;

  const _NumberPropertyRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Create a text controller with the current value
    final controller = TextEditingController(text: value.toStringAsFixed(1));

    // Use StatefulBuilder to properly manage the dragging state
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          Expanded(
            child: StatefulBuilder(
              builder: (context, setState) {
                // Create state variables outside the builder function as private properties
                return _DraggableValueField(
                  controller: controller,
                  value: value,
                  label: label,
                  onChanged: onChanged,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Create a new StatefulWidget to properly track dragging state
class _DraggableValueField extends StatefulWidget {
  final TextEditingController controller;
  final double value;
  final String label;
  final Function(double) onChanged;

  const _DraggableValueField({
    required this.controller,
    required this.value,
    required this.label,
    required this.onChanged,
  });

  @override
  State<_DraggableValueField> createState() => _DraggableValueFieldState();
}

class _DraggableValueFieldState extends State<_DraggableValueField> {
  double startX = 0;
  double startValue = 0;
  bool isDragging = false;
  bool isShiftPressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      // Use Listener instead of GestureDetector to detect mouse buttons
      onPointerDown: (PointerDownEvent event) {
        // Check if middle button is pressed (button index 2 corresponds to middle button)
        if (event.buttons == 4) {
          // 4 is middle button
          setState(() {
            startX = event.localPosition.dx;
            startValue = widget.value;
            isDragging = true;
            // Check if shift key is pressed for precision mode
            isShiftPressed = event.down && (event.buttons & 0x8) != 0;
          });
        }
      },
      onPointerMove: (PointerMoveEvent event) {
        if (isDragging) {
          // Calculate delta and apply a sensitivity factor
          final dx = event.localPosition.dx - startX;

          // Check if shift key is currently pressed
          bool newShiftPressed = (event.buttons & 0x8) != 0;
          if (isShiftPressed != newShiftPressed) {
            setState(() {
              isShiftPressed = newShiftPressed;
            });
          }

          // Determine the adjustment factor based on precision mode and value magnitude
          double adjustmentFactor;

          if (isShiftPressed) {
            // Precision mode (slow changes) with Shift key
            adjustmentFactor = 0.05; // Very fine control

            if (widget.label == 'Rotation') {
              adjustmentFactor = 0.02; // Even finer for rotation
            }
          } else {
            // Fast mode (without Shift key)
            adjustmentFactor = 0.5; // Reduced from 5.0 for better control

            if (startValue.abs() > 100) {
              adjustmentFactor = 1.0; // Reduced from 10.0
            }

            if (widget.label == 'Rotation') {
              adjustmentFactor = 0.2; // Reduced from 2.0
            }
          }

          // Calculate new value with the appropriate sensitivity
          final newValue = startValue + (dx * adjustmentFactor);

          // Optionally round to 1 decimal place for better usability
          final roundedValue = (newValue * 10).round() / 10;

          // Update the controller text and call the callback
          widget.controller.text = roundedValue.toStringAsFixed(1);
          widget.onChanged(roundedValue);
        }
      },
      onPointerUp: (PointerUpEvent event) {
        if (isDragging) {
          setState(() {
            isDragging = false;
          });
        }
      },
      child: Stack(
        children: [
          TextField(
            controller: widget.controller,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
            onChanged: (text) {
              final newValue = double.tryParse(text);
              if (newValue != null) {
                widget.onChanged(newValue);
              }
            },
            mouseCursor: SystemMouseCursors.resizeLeftRight,
          ),

          // Now the tooltip will properly show when isDragging is true
          if (isDragging)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isShiftPressed
                            ? Colors.blue.withOpacity(0.7)
                            : Colors.orange.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isShiftPressed ? 'Fine' : 'Fast',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SwitchPropertyRow extends StatelessWidget {
  final String label;
  final bool value;
  final Function(bool) onChanged;

  const _SwitchPropertyRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// Helper widget to display a property
class _DisplayProperty extends StatelessWidget {
  final String label;
  final String value;

  const _DisplayProperty({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Text(value),
            ),
          ),
        ],
      ),
    );
  }
}

// Main properties panel class
class PropertiesPanel extends StatelessWidget {
  final LayoutElement element;

  const PropertiesPanel({super.key, required this.element});

  @override
  Widget build(BuildContext context) {
    final editorProvider = Provider.of<LayoutEditorProvider>(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Theme.of(context).dividerColor)),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Icon(_getElementIcon(element.type)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Properties: ${_getElementTitle(element)}',
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Properties content in scrollable area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Common properties section
                  const _SectionHeader(title: 'General'),

                  // Position
                  _NumberPropertyRow(
                    label: 'X',
                    value: element.x,
                    onChanged: (value) {
                      editorProvider.updateElementPosition(
                        element.id,
                        Offset(value, element.y),
                      );
                    },
                  ),
                  _NumberPropertyRow(
                    label: 'Y',
                    value: element.y,
                    onChanged: (value) {
                      editorProvider.updateElementPosition(
                        element.id,
                        Offset(element.x, value),
                      );
                    },
                  ),

                  // Size
                  _NumberPropertyRow(
                    label: 'Width',
                    value: element.width,
                    onChanged: (value) {
                      editorProvider.updateElementSize(
                        element.id,
                        Size(value, element.height),
                      );
                    },
                  ),
                  _NumberPropertyRow(
                    label: 'Height',
                    value: element.height,
                    onChanged: (value) {
                      editorProvider.updateElementSize(
                        element.id,
                        Size(element.width, value),
                      );
                    },
                  ),

                  // Rotation
                  _NumberPropertyRow(
                    label: 'Rotation',
                    value: element.rotation,
                    onChanged: (value) {
                      editorProvider.updateElementRotation(element.id, value);
                    },
                  ),

                  // Visibility and Lock
                  _SwitchPropertyRow(
                    label: 'Visible',
                    value: element.isVisible,
                    onChanged: (value) {
                      editorProvider.toggleElementVisibility(element.id);
                    },
                  ),
                  _SwitchPropertyRow(
                    label: 'Locked',
                    value: element.isLocked,
                    onChanged: (value) {
                      editorProvider.toggleElementLock(element.id);
                    },
                  ),

                  const SizedBox(height: 16),
                  const Divider(),

                  // Type-specific properties
                  if (element.type == 'image')
                    _buildImageProperties(
                      element as ImageElement,
                      editorProvider,
                    ),
                  if (element.type == 'text')
                    _buildTextProperties(
                      element as TextElement,
                      editorProvider,
                    ),
                  if (element.type == 'camera')
                    _buildCameraProperties(
                      element as CameraElement,
                      editorProvider,
                    ),
                  if (element.type == 'group')
                    _buildGroupProperties(
                      element as GroupElement,
                      editorProvider,
                    ),

                  const SizedBox(height: 24),

                  // Element actions
                  const _SectionHeader(title: 'Actions'),

                  // Replace the grid layout with a column of buttons
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Duplicate Element'),
                        onPressed: () {
                          editorProvider.copyElement(element.id);
                          editorProvider.pasteElement();
                        },
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.vertical_align_top, size: 18),
                        label: const Text('Bring to Front'),
                        onPressed: () {
                          editorProvider.bringToFront(element.id);
                        },
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.vertical_align_bottom, size: 18),
                        label: const Text('Send to Back'),
                        onPressed: () {
                          editorProvider.sendToBack(element.id);
                        },
                      ),

                      // Add ungroup button for groups
                      if (element.type == 'group') ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.group_remove, size: 18),
                          label: const Text('Ungroup Elements'),
                          onPressed: () {
                            editorProvider.ungroupSelectedElements();
                          },
                        ),
                      ],

                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Delete Element'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.errorContainer,
                          foregroundColor:
                              Theme.of(context).colorScheme.onErrorContainer,
                        ),
                        onPressed: () {
                          editorProvider.deleteElement(element.id);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageProperties(
    ImageElement element,
    LayoutEditorProvider editorProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Image Properties'),

        // Image path
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('File Path', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                width: double.infinity,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        element.path.split('/').last,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 16),
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.image,
                          allowMultiple: false,
                        );

                        if (result != null &&
                            result.files.isNotEmpty &&
                            result.files.first.path != null) {
                          editorProvider.updateImageElement(
                            element.id,
                            path: result.files.first.path!,
                          );
                        }
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 30,
                        minHeight: 30,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Aspect Ratio Lock - NEW
        _SwitchPropertyRow(
          label: 'Lock Ratio',
          value: element.aspectRatioLocked,
          onChanged: (value) {
            editorProvider.updateImageElement(
              element.id,
              aspectRatioLocked: value,
            );
          },
        ),

        // Opacity
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Opacity', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: element.opacity,
                      min: 0.0,
                      max: 1.0,
                      divisions: 100,
                      onChanged: (value) {
                        editorProvider.updateImageElement(
                          element.id,
                          opacity: value,
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${(element.opacity * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Image info - NEW
        Container(
          margin: const EdgeInsets.only(top: 8, bottom: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.aspect_ratio, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Aspect Ratio: ${(element.width / element.height).toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.photo, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            element.path.split('/').last,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextProperties(
    TextElement element,
    LayoutEditorProvider editorProvider,
  ) {
    // Use TextEditingController with proper text direction
    final TextEditingController textController = TextEditingController(
      text: element.text,
    );

    // Set text selection to end to ensure cursor is at the end when editing
    textController.selection = TextSelection.fromPosition(
      TextPosition(offset: textController.text.length),
    );

    // Keep the slider values in sync with the element properties
    double fontSize = element.fontSize;
    Color textColor = _hexToColor(element.color);
    Color backgroundColor = _hexToColor(element.backgroundColor);

    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(title: 'Text Properties'),

            // Text content with fixed text direction
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Content', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: textController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    textDirection:
                        TextDirection.ltr, // Ensure left-to-right text input
                    minLines: 1,
                    maxLines: 3,
                    onChanged: (value) {
                      editorProvider.updateTextElement(element.id, text: value);
                    },
                  ),
                ],
              ),
            ),

            // Font family with custom selector
            Container(
              margin: const EdgeInsets.only(
                bottom: 16,
              ), // Increased margin for better spacing
              child: CustomFontSelector(
                currentFont: element.fontFamily,
                onFontSelected: (selectedFont) {
                  editorProvider.updateTextElement(
                    element.id,
                    fontFamily: selectedFont,
                  );
                },
              ),
            ),

            // Font size
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Font Size', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: fontSize,
                          min: 8,
                          max: 72,
                          divisions: 64,
                          onChanged: (value) {
                            setState(() {
                              fontSize = value;
                            });
                            editorProvider.updateTextElement(
                              element.id,
                              fontSize: value,
                            );
                          },
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${fontSize.round()}px',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Font style
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Font Style', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Bold'),
                        selected: element.isBold,
                        onSelected: (selected) {
                          editorProvider.updateTextElement(
                            element.id,
                            isBold: selected,
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Italic'),
                        selected: element.isItalic,
                        onSelected: (selected) {
                          editorProvider.updateTextElement(
                            element.id,
                            isItalic: selected,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Text alignment
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Alignment', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),

                  // First row of alignment options (Top)
                  Row(
                    children: [
                      Expanded(
                        child: _buildAlignmentButton(
                          context: context,
                          icon: Icons.align_horizontal_left,
                          alignment: 'topLeft',
                          currentAlignment: element.alignment,
                          onTap: () {
                            editorProvider.updateTextElement(
                              element.id,
                              alignment: 'topLeft',
                            );
                          },
                          label: 'Top Left',
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _buildAlignmentButton(
                          context: context,
                          icon: Icons.align_horizontal_center,
                          alignment: 'topCenter',
                          currentAlignment: element.alignment,
                          onTap: () {
                            editorProvider.updateTextElement(
                              element.id,
                              alignment: 'topCenter',
                            );
                          },
                          label: 'Top Center',
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _buildAlignmentButton(
                          context: context,
                          icon: Icons.align_horizontal_right,
                          alignment: 'topRight',
                          currentAlignment: element.alignment,
                          onTap: () {
                            editorProvider.updateTextElement(
                              element.id,
                              alignment: 'topRight',
                            );
                          },
                          label: 'Top Right',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Second row of alignment options (Middle)
                  Row(
                    children: [
                      Expanded(
                        child: _buildAlignmentButton(
                          context: context,
                          icon: Icons.format_align_left,
                          alignment: 'centerLeft',
                          currentAlignment: element.alignment,
                          onTap: () {
                            editorProvider.updateTextElement(
                              element.id,
                              alignment: 'centerLeft',
                            );
                          },
                          label: 'Center Left',
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _buildAlignmentButton(
                          context: context,
                          icon: Icons.format_align_center,
                          alignment: 'center',
                          currentAlignment: element.alignment,
                          onTap: () {
                            editorProvider.updateTextElement(
                              element.id,
                              alignment: 'center',
                            );
                          },
                          label: 'Center',
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _buildAlignmentButton(
                          context: context,
                          icon: Icons.format_align_right,
                          alignment: 'centerRight',
                          currentAlignment: element.alignment,
                          onTap: () {
                            editorProvider.updateTextElement(
                              element.id,
                              alignment: 'centerRight',
                            );
                          },
                          label: 'Center Right',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Third row of alignment options (Bottom)
                  Row(
                    children: [
                      Expanded(
                        child: _buildAlignmentButton(
                          context: context,
                          icon: Icons.vertical_align_bottom_outlined,
                          alignment: 'bottomLeft',
                          currentAlignment: element.alignment,
                          onTap: () {
                            editorProvider.updateTextElement(
                              element.id,
                              alignment: 'bottomLeft',
                            );
                          },
                          label: 'Bottom Left',
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _buildAlignmentButton(
                          context: context,
                          icon: Icons.vertical_align_center_outlined,
                          alignment: 'bottomCenter',
                          currentAlignment: element.alignment,
                          onTap: () {
                            editorProvider.updateTextElement(
                              element.id,
                              alignment: 'bottomCenter',
                            );
                          },
                          label: 'Bottom Center',
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _buildAlignmentButton(
                          context: context,
                          icon: Icons.vertical_align_top_outlined,
                          alignment: 'bottomRight',
                          currentAlignment: element.alignment,
                          onTap: () {
                            editorProvider.updateTextElement(
                              element.id,
                              alignment: 'bottomRight',
                            );
                          },
                          label: 'Bottom Right',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Colors
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Colors', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final Color? pickedColor = await showDialog<Color>(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    title: const Text('Pick Text Color'),
                                    content: SingleChildScrollView(
                                      child: ColorPicker(
                                        pickerColor: textColor,
                                        onColorChanged: (color) {
                                          setState(() {
                                            textColor = color;
                                          });
                                        },
                                        pickerAreaHeightPercent: 0.8,
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () => Navigator.of(context).pop(),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed:
                                            () => Navigator.of(
                                              context,
                                            ).pop(textColor),
                                        child: const Text('Select'),
                                      ),
                                    ],
                                  ),
                            );

                            if (pickedColor != null) {
                              final textColorHex =
                                  '#${pickedColor.value.toRadixString(16).padLeft(8, '0').substring(2)}';
                              editorProvider.updateTextElement(
                                element.id,
                                color: textColorHex,
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: textColor,
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Text Color',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            // Define a flag for transparency
                            bool isTransparent =
                                backgroundColor == Colors.transparent;

                            final Color? pickedColor = await showDialog<Color>(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    title: const Text('Pick Background Color'),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Add a checkbox for transparency
                                          CheckboxListTile(
                                            title: const Text(
                                              'Transparent Background',
                                            ),
                                            value: isTransparent,
                                            onChanged: (value) {
                                              setState(() {
                                                isTransparent = value ?? false;
                                                if (isTransparent) {
                                                  backgroundColor =
                                                      Colors.transparent;
                                                }
                                              });
                                            },
                                          ),
                                          const SizedBox(height: 10),
                                          // Only show color picker if not transparent
                                          if (!isTransparent)
                                            ColorPicker(
                                              pickerColor: backgroundColor,
                                              onColorChanged: (color) {
                                                setState(() {
                                                  backgroundColor = color;
                                                });
                                              },
                                              pickerAreaHeightPercent: 0.8,
                                              enableAlpha:
                                                  true, // Enable alpha channel for transparency
                                            ),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () => Navigator.of(context).pop(),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          if (isTransparent) {
                                            // Return a special marker for transparency
                                            Navigator.of(
                                              context,
                                            ).pop(const Color(0x00000000));
                                          } else {
                                            Navigator.of(
                                              context,
                                            ).pop(backgroundColor);
                                          }
                                        },
                                        child: const Text('Select'),
                                      ),
                                    ],
                                  ),
                            );

                            if (pickedColor != null) {
                              final backgroundColorHex =
                                  pickedColor == const Color(0x00000000)
                                      ? 'transparent'
                                      : '#${pickedColor.value.toRadixString(16).padLeft(8, '0')}';

                              editorProvider.updateTextElement(
                                element.id,
                                backgroundColor: backgroundColorHex,
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: backgroundColor,
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Background',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCameraProperties(
    CameraElement element,
    LayoutEditorProvider editorProvider,
  ) {
    final TextEditingController labelController = TextEditingController(
      text: element.label,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Camera Properties'),

        // Camera label
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Label', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              TextField(
                controller: labelController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  isDense: true,
                ),
                onChanged: (value) {
                  editorProvider.updateCameraElement(element.id, label: value);
                },
              ),
            ],
          ),
        ),

        // Camera info
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text(
                    'Camera Spot Information',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'This element represents a camera spot where photos will be placed. '
                'The size and position of this element will determine how the captured '
                'photos are displayed in the final layout.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGroupProperties(
    GroupElement element,
    LayoutEditorProvider editorProvider,
  ) {
    final TextEditingController nameController = TextEditingController(
      text: element.name,
    );

    // Get children to show stats
    final childElements = editorProvider.getGroupChildren(element.id);
    final imageCount = childElements.where((e) => e.type == 'image').length;
    final textCount = childElements.where((e) => e.type == 'text').length;
    final cameraCount = childElements.where((e) => e.type == 'camera').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Group Properties'),

        // Group name field
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Group Name', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  isDense: true,
                ),
                onChanged: (value) {
                  editorProvider.updateGroupName(element.id, value);
                },
              ),
            ],
          ),
        ),

        // Group statistics
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Group Contents',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.image, size: 16),
                  const SizedBox(width: 8),
                  Text('Images: $imageCount'),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.text_fields, size: 16),
                  const SizedBox(width: 8),
                  Text('Text Elements: $textCount'),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.camera_alt, size: 16),
                  const SizedBox(width: 8),
                  Text('Camera Spots: $cameraCount'),
                ],
              ),
              const SizedBox(height: 4),
              const Divider(),
              Row(
                children: [
                  const Icon(Icons.layers, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Total Elements: ${childElements.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Help text
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'About Groups',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Groups allow you to organize and manipulate multiple elements together. '
                'Move, resize, or rotate the group to affect all elements within it.',
                style: TextStyle(fontSize: 12),
              ),
              SizedBox(height: 8),
              Text(
                'Tip: Press Ctrl+G to group elements and Ctrl+Shift+G to ungroup.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAlignmentButton({
    required BuildContext context,
    required IconData icon,
    required String alignment,
    required String currentAlignment,
    required VoidCallback onTap,
    String? label,
  }) {
    final isSelected = alignment == currentAlignment;

    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerLowest,
              border: Border.all(
                color:
                    isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                          context,
                        ).colorScheme.outline.withOpacity(0.5),
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 18,
              color:
                  isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color:
                      isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.8),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  IconData _getElementIcon(String type) {
    switch (type) {
      case 'image':
        return Icons.image;
      case 'text':
        return Icons.text_fields;
      case 'camera':
        return Icons.camera_alt;
      case 'group':
        return Icons.folder;
      default:
        return Icons.help_outline;
    }
  }

  String _getElementTitle(LayoutElement element) {
    switch (element.type) {
      case 'image':
        final path = (element as ImageElement).path;
        final filename = path.split('/').last;
        return filename.length > 20
            ? '${filename.substring(0, 17)}...'
            : filename;
      case 'text':
        final text = (element as TextElement).text;
        return text.length > 20 ? '${text.substring(0, 17)}...' : text;
      case 'camera':
        return (element as CameraElement).label;
      case 'group':
        return (element as GroupElement).name;
      default:
        return 'Unknown Element';
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

// Fix the CustomFontSelector class that has syntax errors

class CustomFontSelector extends StatefulWidget {
  final String currentFont;
  final Function(String) onFontSelected;

  const CustomFontSelector({
    super.key,
    required this.currentFont,
    required this.onFontSelected,
  });

  @override
  _CustomFontSelectorState createState() => _CustomFontSelectorState();
}

class _CustomFontSelectorState extends State<CustomFontSelector> {
  // Replace the hardcoded fonts list with an empty list that will be populated
  List<String> systemFonts = [];

  // List to hold Google Fonts
  List<String> googleFontsList = [];

  // Combined list of all fonts
  List<String> get allFonts => [...systemFonts, ...googleFontsList];

  final TextEditingController _controller = TextEditingController();
  bool _isDropdownVisible = false;
  String _searchText = '';
  bool _isLoading = false;
  bool _googleFontsLoaded = false;
  bool _systemFontsLoaded = false;

  // Add a focus node for the search field
  final FocusNode _searchFocusNode = FocusNode();

  // Add map to store font file paths
  Map<String, String> fontPaths = {};

  @override
  void initState() {
    super.initState();
    _controller.text = widget.currentFont;

    // Load system fonts from Windows Fonts directory
    _loadSystemFonts();

    // Pre-fetch Google Fonts list when the widget initializes
    _loadGoogleFonts();
  }

  // New method to load fonts from Windows Fonts directory with better detection
  Future<void> _loadSystemFonts() async {
    setState(() {
      _isLoading = true;
    });

    if (!Platform.isWindows) {
      _setDefaultFonts();
      return;
    }

    try {
      final fontsDir = Directory('C:\\Windows\\Fonts');
      if (await fontsDir.exists()) {
        List<FileSystemEntity> fontFiles = await fontsDir.list().toList();
        Set<String> fontNames = {};

        for (var file in fontFiles) {
          if (file is File) {
            String path = file.path.toLowerCase();
            if (path.endsWith('.ttf') ||
                path.endsWith('.otf') ||
                path.endsWith('.ttc')) {
              // Extract filename without extension
              String rawName = file.path.split('\\').last;

              // Clean up font name more thoroughly
              String fontName = _extractFontFamilyName(rawName);

              // Only add if name is not empty after cleaning
              if (fontName.isNotEmpty) {
                fontNames.add(fontName);
                // Store the full path for later use
                fontPaths[fontName] = file.path;

                // Also add the raw name (without extension) as fallback
                String rawNameWithoutExt = rawName.replaceAll(
                  RegExp(r'\.(ttf|otf|ttc)$', caseSensitive: false),
                  '',
                );
                if (rawNameWithoutExt.isNotEmpty) {
                  fontNames.add(rawNameWithoutExt);
                  fontPaths[rawNameWithoutExt] = file.path;
                }
              }
            }
          }
        }

        // Convert to sorted list
        List<String> sortedFonts = fontNames.toList()..sort();

        // Update the state
        setState(() {
          systemFonts = sortedFonts;
          _systemFontsLoaded = true;
          if (_googleFontsLoaded) {
            _isLoading = false;
          }
        });

        print('Loaded ${sortedFonts.length} system fonts');

        // Try to preload the currently selected font if it's a system font
        if (systemFonts.contains(widget.currentFont)) {
          _preloadFont(widget.currentFont);
        }
      } else {
        print('Windows Fonts directory not found');
        _setDefaultFonts();
      }
    } catch (e) {
      print('Error loading system fonts: $e');
      _setDefaultFonts();
    }
  }

  void _setDefaultFonts() {
    setState(() {
      systemFonts = ['Arial', 'Times New Roman', 'Helvetica', 'Courier New'];
      _systemFontsLoaded = true;
      if (_googleFontsLoaded) {
        _isLoading = false;
      }
    });
  }

  // Helper method to clean up font names
  String _cleanFontName(String name) {
    // Remove common suffixes like Regular, Bold, Italic
    final suffixes = [
      'regular',
      'bold',
      'italic',
      'light',
      'medium',
      'black',
      'thin',
    ];

    // Convert underscores to spaces
    name = name.replaceAll('_', ' ');

    // Try to handle font naming conventions
    for (var suffix in suffixes) {
      if (name.toLowerCase().endsWith(suffix)) {
        name = name.substring(0, name.length - suffix.length).trim();
      }
    }

    // Handle common font family markers
    if (name.contains('-')) {
      // Many fonts use FamilyName-StyleName format
      name = name.split('-').first.trim();
    }

    return name;
  }

  // Load Google Fonts asynchronously
  Future<void> _loadGoogleFonts() async {
    if (_googleFontsLoaded) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get all available Google Fonts
      final availableFonts = GoogleFonts.asMap().keys.toList();

      // Update the state with the fetched fonts
      setState(() {
        googleFontsList = availableFonts;
        _googleFontsLoaded = true;
        if (_systemFontsLoaded) {
          _isLoading = false;
        }
      });
    } catch (e) {
      print('Error loading Google Fonts: $e');
      setState(() {
        _googleFontsLoaded = true;
        if (_systemFontsLoaded) {
          _isLoading = false;
        }
      });
    }
  }

  Future<void> _preloadFont(String fontName) async {
    if (!fontPaths.containsKey(fontName)) return;

    try {
      final fontFile = File(fontPaths[fontName]!);
      if (await fontFile.exists()) {
        final fontLoader = FontLoader(fontName);
        final bytes = await fontFile.readAsBytes();
        fontLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
        await fontLoader.load();
      }
    } catch (e) {
      print('Error preloading font $fontName: $e');
    }
  }

  // Update the font selection to preload the font
  void _selectFont(String font) {
    setState(() {
      _controller.text = font;
      _isDropdownVisible = false;
    });

    // Preload the font if it's a system font
    if (systemFonts.contains(font)) {
      _preloadFont(font);
    }

    widget.onFontSelected(font);
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<String> _getFilteredFonts() {
    if (_searchText.isEmpty) {
      return allFonts;
    }
    return allFonts
        .where((font) => font.toLowerCase().contains(_searchText.toLowerCase()))
        .toList();
  }

  // Helper to check if a font is a Google Font
  bool _isGoogleFont(String fontName) {
    return googleFontsList.contains(fontName);
  }

  // Helper to check if a font is a System Font
  bool _isSystemFont(String fontName) {
    return systemFonts.contains(fontName);
  }

  // Helper to get appropriate TextStyle for font preview
  TextStyle _getFontStyle(String fontName, {bool isBold = false}) {
    if (_isGoogleFont(fontName)) {
      return GoogleFonts.getFont(
        fontName,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      );
    } else {
      return TextStyle(
        fontFamily: fontName,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      );
    }
  }

  String _extractFontFamilyName(String filename) {
    // Remove file extension
    String name = filename.replaceAll(
      RegExp(r'\.(ttf|otf|ttc)$', caseSensitive: false),
      '',
    );

    // Convert special characters to spaces
    name = name.replaceAll(RegExp(r'[-_]'), ' ');

    // Split into words
    List<String> words = name.split(' ');

    // Convert to title case and handle special cases
    words =
        words
            .map((word) {
              if (word.isEmpty) return '';
              // Keep original casing for single characters (like iTerm)
              if (word.length == 1) return word;
              // Capitalize first letter, lowercase rest
              return word[0].toUpperCase() + word.substring(1).toLowerCase();
            })
            .where((w) => w.isNotEmpty)
            .toList();

    // Join words back together
    return words.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label for font family field
        const Padding(
          padding: EdgeInsets.only(bottom: 4.0),
          child: Text('Font Family', style: TextStyle(fontSize: 12)),
        ),

        // Font selector field
        TextField(
          controller: _controller,
          readOnly: true,
          decoration: InputDecoration(
            hintText: 'Select a font...',
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_controller.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      setState(() {
                        _controller.clear();
                        widget.onFontSelected('Arial');
                      });
                    },
                    tooltip: 'Reset to default font',
                  ),
                Icon(
                  _isDropdownVisible
                      ? Icons.arrow_drop_up
                      : Icons.arrow_drop_down,
                ),
              ],
            ),
            // Show font source indicator
            prefixIcon:
                _controller.text.isNotEmpty
                    ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Icon(
                        _isGoogleFont(_controller.text)
                            ? Icons.cloud_outlined
                            : Icons.computer_outlined,
                        size: 18,
                        color:
                            _isGoogleFont(_controller.text)
                                ? Colors.blue[300]
                                : Colors.green[300],
                      ),
                    )
                    : null,
          ),
          style:
              _controller.text.isNotEmpty
                  ? _getFontStyle(_controller.text)
                  : null,
          onTap: () {
            setState(() {
              _isDropdownVisible = !_isDropdownVisible;
              _searchText = '';

              // If dropdown is opened, request focus on the search field after the frame is built
              if (_isDropdownVisible) {
                // Use Future.delayed to ensure the focus happens after the build
                Future.delayed(Duration.zero, () {
                  _searchFocusNode.requestFocus();
                });

                // Make sure Google Fonts are loaded
                if (!_googleFontsLoaded) {
                  _loadGoogleFonts();
                }
              }
            });
          },
        ),

        // Current font preview
        if (_controller.text.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isGoogleFont(_controller.text)
                          ? Icons.cloud_outlined
                          : Icons.computer_outlined,
                      size: 14,
                      color:
                          _isGoogleFont(_controller.text)
                              ? Colors.blue[300]
                              : Colors.green[300],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isGoogleFont(_controller.text)
                          ? "Google Font"
                          : "System Font",
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            _isGoogleFont(_controller.text)
                                ? Colors.blue[700]
                                : Colors.green[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'AaBbCcDdEeFf 123456',
                  style: _getFontStyle(_controller.text),
                ),
              ],
            ),
          ),

        // Dropdown with search field
        if (_isDropdownVisible)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search box
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    focusNode: _searchFocusNode,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search fonts...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      isDense: true,
                      border: const OutlineInputBorder(),
                      // Show loading indicator while fetching Google Fonts
                      suffixIcon:
                          _isLoading
                              ? Container(
                                width: 20,
                                height: 20,
                                padding: const EdgeInsets.all(8),
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : null,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchText = value;
                      });
                    },
                    onSubmitted: (value) {
                      final filteredFonts = _getFilteredFonts();
                      if (filteredFonts.isNotEmpty) {
                        final firstFont = filteredFonts.first;
                        setState(() {
                          _controller.text = firstFont;
                          _isDropdownVisible = false;
                          widget.onFontSelected(firstFont);
                        });
                      }
                    },
                  ),
                ),

                // Font categories
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Chip(
                          avatar: Icon(
                            Icons.computer_outlined,
                            size: 18,
                            color: Colors.green[700],
                          ),
                          label: Text(
                            'System Fonts (${_systemFontsLoaded ? systemFonts.where((font) => font.toLowerCase().contains(_searchText.toLowerCase())).length : "..."})',
                            style: TextStyle(fontSize: 12),
                          ),
                          backgroundColor: Colors.green[50],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Chip(
                          avatar: Icon(
                            Icons.cloud_outlined,
                            size: 18,
                            color: Colors.blue[700],
                          ),
                          label: Text(
                            'Google Fonts (${_googleFontsLoaded ? googleFontsList.where((font) => font.toLowerCase().contains(_searchText.toLowerCase())).length : "..."})',
                            style: TextStyle(fontSize: 12),
                          ),
                          backgroundColor: Colors.blue[50],
                        ),
                      ),
                    ],
                  ),
                ),

                // Fonts list with sections
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child:
                      _isLoading && !_googleFontsLoaded
                          ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('Loading Google Fonts...'),
                              ],
                            ),
                          )
                          : ListView(
                            shrinkWrap: true,
                            children: [
                              // Header for system fonts - only show on Windows
                              if (Platform.isWindows &&
                                  _getFilteredFonts().any(
                                    (font) => systemFonts.contains(font),
                                  ))
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                    vertical: 4.0,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.computer_outlined,
                                        size: 16,
                                        color: Colors.green[700],
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Windows System Fonts (${systemFonts.length} detected)',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green[700],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // System fonts list
                              ..._getFilteredFonts()
                                  .where((font) => systemFonts.contains(font))
                                  .map((font) => _buildFontListTile(font)),

                              // Header for Google fonts
                              if (_getFilteredFonts().any(
                                (font) => googleFontsList.contains(font),
                              ))
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                    vertical: 4.0,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.cloud_outlined,
                                        size: 16,
                                        color: Colors.blue[700],
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Google Fonts',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // Google fonts list
                              ..._getFilteredFonts()
                                  .where(
                                    (font) => googleFontsList.contains(font),
                                  )
                                  .map((font) => _buildFontListTile(font)),
                            ],
                          ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Helper method to build font list tile with proper styling
  Widget _buildFontListTile(String font) {
    final isSelected = font == _controller.text;
    final isGoogleFont = _isGoogleFont(font);
    final iconColor = isGoogleFont ? Colors.blue[300] : Colors.green[300];
    final icon = isGoogleFont ? Icons.cloud_outlined : Icons.computer_outlined;

    return ListTile(
      dense: true,
      title: Text(font, style: _getFontStyle(font, isBold: isSelected)),
      selected: isSelected,
      leading: Icon(icon, size: 16, color: iconColor),
      trailing:
          isSelected
              ? Icon(
                Icons.check,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              )
              : null,
      onTap: () => _selectFont(font),
      tileColor:
          isSelected
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
              : null,
      subtitle: Text(
        'AaBbCc 123',
        style: _getFontStyle(font).copyWith(fontSize: 10),
      ),
    );
  }
}
