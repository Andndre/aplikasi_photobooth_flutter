import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../models/layouts.dart';
import '../../providers/layout_editor.dart';

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

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              onChanged: (text) {
                final newValue = double.tryParse(text);
                if (newValue != null) {
                  onChanged(newValue);
                }
              },
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

  const PropertiesPanel({Key? key, required this.element}) : super(key: key);

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
            color: Theme.of(context).colorScheme.surfaceVariant,
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

                  const SizedBox(height: 24),

                  // Element actions
                  const _SectionHeader(title: 'Actions'),

                  // Delete and Duplicate buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.delete, size: 18),
                          label: const Text('Delete'),
                          onPressed: () {
                            editorProvider.deleteElement(element.id);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('Duplicate'),
                          onPressed: () {
                            editorProvider.copyElement(element.id);
                            editorProvider.pasteElement();
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Arrange buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.vertical_align_top, size: 18),
                          label: const Text('Bring to Front'),
                          onPressed: () {
                            editorProvider.bringToFront(element.id);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(
                            Icons.vertical_align_bottom,
                            size: 18,
                          ),
                          label: const Text('Send to Back'),
                          onPressed: () {
                            editorProvider.sendToBack(element.id);
                          },
                        ),
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

            // Font family
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Font Family', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    value: element.fontFamily,
                    items:
                        [
                          'Arial',
                          'Helvetica',
                          'Times New Roman',
                          'Courier',
                          'Verdana',
                        ].map((font) {
                          return DropdownMenuItem<String>(
                            value: font,
                            child: Text(font),
                          );
                        }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        editorProvider.updateTextElement(
                          element.id,
                          fontFamily: value,
                        );
                      }
                    },
                  ),
                ],
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
                  Row(
                    children: [
                      _buildAlignmentButton(
                        context: context,
                        icon: Icons.format_align_left,
                        alignment: 'left',
                        currentAlignment: element.alignment,
                        onTap: () {
                          editorProvider.updateTextElement(
                            element.id,
                            alignment: 'left',
                          );
                        },
                      ),
                      _buildAlignmentButton(
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
                      ),
                      _buildAlignmentButton(
                        context: context,
                        icon: Icons.format_align_right,
                        alignment: 'right',
                        currentAlignment: element.alignment,
                        onTap: () {
                          editorProvider.updateTextElement(
                            element.id,
                            alignment: 'right',
                          );
                        },
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
                                const Text('Text Color'),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final Color? pickedColor = await showDialog<Color>(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    title: const Text('Pick Background Color'),
                                    content: SingleChildScrollView(
                                      child: ColorPicker(
                                        pickerColor: backgroundColor,
                                        onColorChanged: (color) {
                                          setState(() {
                                            backgroundColor = color;
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
                                            ).pop(backgroundColor),
                                        child: const Text('Select'),
                                      ),
                                    ],
                                  ),
                            );

                            if (pickedColor != null) {
                              final backgroundColorHex =
                                  '#${pickedColor.value.toRadixString(16).padLeft(8, '0').substring(2)}';
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
                                const Text('Background'),
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

  Widget _buildAlignmentButton({
    required BuildContext context,
    required IconData icon,
    required String alignment,
    required String currentAlignment,
    required VoidCallback onTap,
  }) {
    final isSelected = alignment == currentAlignment;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
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
                      : Theme.of(context).colorScheme.outline.withOpacity(0.5),
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color:
                isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
          ),
        ),
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
