import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../models/layouts.dart';
import '../../providers/layout_editor.dart';
import '../export_dialog.dart';

class BackgroundPropertiesPanel extends StatelessWidget {
  const BackgroundPropertiesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final editorProvider = Provider.of<LayoutEditorProvider>(context);
    final layout = editorProvider.layout;

    if (layout == null) {
      return const Center(child: Text('No layout loaded'));
    }

    Color backgroundColor = _hexToColor(layout.backgroundColor);

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
                const Icon(Icons.crop_square),
                const SizedBox(width: 8),
                Text(
                  'Layout Properties',
                  style: Theme.of(context).textTheme.titleMedium,
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
                  // Background color section
                  const _SectionHeader(title: 'Background'),

                  // Fix color picker button implementation
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text(
                            'Color',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              // Store current color for color picker
                              Color pickerColor = _hexToColor(
                                layout.backgroundColor,
                              );

                              // Debug print
                              print(
                                'Current background color: ${layout.backgroundColor}',
                              );

                              // Show color picker dialog with stateful color selection
                              Color? resultColor = await showDialog<Color>(
                                context: context,
                                builder: (BuildContext context) {
                                  Color currentColor = pickerColor;
                                  return StatefulBuilder(
                                    builder: (context, setState) {
                                      return AlertDialog(
                                        title: const Text(
                                          'Pick Background Color',
                                        ),
                                        content: SingleChildScrollView(
                                          child: ColorPicker(
                                            pickerColor: currentColor,
                                            onColorChanged: (Color color) {
                                              setState(
                                                () => currentColor = color,
                                              );
                                            },
                                            pickerAreaHeightPercent: 0.8,
                                          ),
                                        ),
                                        actions: <Widget>[
                                          TextButton(
                                            onPressed:
                                                () =>
                                                    Navigator.of(context).pop(),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed:
                                                () => Navigator.of(
                                                  context,
                                                ).pop(currentColor),
                                            child: const Text('Apply'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              );

                              // Handle selected color
                              if (resultColor != null) {
                                final colorHex =
                                    // '#${resultColor.value.toRadixString(16).padLeft(8, '0').substring(2)}';
                                    '#${resultColor.toHexString()}';
                                print('New background color: $colorHex');
                                editorProvider.updateLayoutBackground(colorHex);
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
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: _hexToColor(
                                        layout.backgroundColor,
                                      ),
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    layout.backgroundColor,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Editor Settings section - NEW!
                  const _SectionHeader(title: 'Editor Settings'),

                  // Grid and Snap to Grid switches
                  SwitchListTile(
                    title: const Text('Show Grid'),
                    value: editorProvider.showGrid,
                    dense: true,
                    contentPadding: const EdgeInsets.all(0),
                    onChanged: (value) => editorProvider.toggleGrid(),
                  ),

                  SwitchListTile(
                    title: const Text('Snap to Grid'),
                    value: editorProvider.snapToGrid,
                    dense: true,
                    contentPadding: const EdgeInsets.all(0),
                    onChanged: (value) => editorProvider.toggleSnapToGrid(),
                  ),

                  const SizedBox(height: 16),

                  // Canvas size section
                  const _SectionHeader(title: 'Canvas Size'),

                  // Width and height (read-only)
                  _DisplayProperty(label: 'Width', value: '${layout.width} px'),
                  _DisplayProperty(
                    label: 'Height',
                    value: '${layout.height} px',
                  ),
                  _DisplayProperty(
                    label: 'Dimensions',
                    value:
                        '${(layout.width / 300).toStringAsFixed(2)} × ${(layout.height / 300).toStringAsFixed(2)} inches',
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Element counts
                  const _SectionHeader(title: 'Elements'),

                  // Count different element types
                  _buildElementCountInfo(layout.elements),

                  const SizedBox(height: 8),

                  // Add elements section
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Add Elements",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),

                        // Buttons to add elements
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildAddElementButton(
                              context: context,
                              icon: Icons.text_fields,
                              label: 'Text',
                              onTap: () => editorProvider.addTextElement(),
                            ),
                            _buildAddElementButton(
                              context: context,
                              icon: Icons.image,
                              label: 'Image',
                              onTap: () async {
                                final result = await FilePicker.platform
                                    .pickFiles(
                                      type: FileType.image,
                                      allowMultiple: false,
                                    );

                                if (result != null &&
                                    result.files.isNotEmpty &&
                                    result.files.first.path != null) {
                                  editorProvider.addImageElement(
                                    result.files.first.path!,
                                  );
                                }
                              },
                            ),
                            _buildAddElementButton(
                              context: context,
                              icon: Icons.camera_alt,
                              label: 'Camera',
                              onTap: () => editorProvider.addCameraElement(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tips section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.tips_and_updates,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Editor Tips',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '• Select an element to edit its properties\n'
                          '• Add camera spots where photos will appear\n'
                          '• Use the bottom toolbar for quick actions\n'
                          '• Save your layout when finished',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Export Layout Section
                  const _SectionHeader(title: 'Export Layout'),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Create an image preview of this layout with sample photos in camera slots.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),

                  ElevatedButton.icon(
                    onPressed: () {
                      // Pass the provider explicitly to the dialog
                      showDialog(
                        context: context,
                        builder:
                            (context) => ExportDialog(
                              layout: layout,
                              editorProvider: editorProvider,
                            ),
                      );
                    },
                    icon: const Icon(Icons.image),
                    label: const Text('Export as Image'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      minimumSize: const Size(double.infinity, 0),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElementCountInfo(List<LayoutElement> elements) {
    final cameraCount = elements.where((e) => e.type == 'camera').length;
    final imageCount = elements.where((e) => e.type == 'image').length;
    final textCount = elements.where((e) => e.type == 'text').length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildElementTypeRow(Icons.camera_alt, 'Camera Spots', cameraCount),
          const SizedBox(height: 6),
          _buildElementTypeRow(Icons.image, 'Images', imageCount),
          const SizedBox(height: 6),
          _buildElementTypeRow(Icons.text_fields, 'Text Elements', textCount),
          const SizedBox(height: 6),
          const Divider(),
          const SizedBox(height: 6),
          _buildElementTypeRow(Icons.layers, 'Total Elements', elements.length),
        ],
      ),
    );
  }

  Widget _buildElementTypeRow(IconData icon, String label, int count) {
    return Row(
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 8),
        Text(label),
        const Spacer(),
        Text(
          count.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildAddElementButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
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

// Helper widgets
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

class _ColorPropertyRow extends StatelessWidget {
  final String label;
  final Color color;
  final Function(Color) onColorChanged;

  const _ColorPropertyRow({
    required this.label,
    required this.color,
    required this.onColorChanged,
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
          Expanded(
            child: InkWell(
              onTap: () async {
                final Color? pickedColor = await showDialog<Color>(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: Text('Pick $label'),
                        content: SingleChildScrollView(
                          child: ColorPicker(
                            pickerColor: color,
                            onColorChanged: (color) {},
                            pickerAreaHeightPercent: 0.8,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(color),
                            child: const Text('Select'),
                          ),
                        ],
                      ),
                );

                if (pickedColor != null) {
                  onColorChanged(pickedColor);
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
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
