import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/layouts.dart';
import '../../providers/layout_editor.dart';

class MultiSelectionPropertiesPanel extends StatelessWidget {
  final List<LayoutElement> selectedElements;

  const MultiSelectionPropertiesPanel({
    Key? key,
    required this.selectedElements,
  }) : super(key: key);

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
                const Icon(Icons.layers),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Multi-Selection: ${selectedElements.length} elements',
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
                  // Selection summary section
                  const _SectionHeader(title: 'Selection Summary'),

                  _buildSelectionSummary(context),

                  const SizedBox(height: 24),

                  // Alignment section
                  const _SectionHeader(title: 'Alignment'),

                  // Horizontal alignment
                  Text(
                    'Horizontal Alignment',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildAlignmentButton(
                          context: context,
                          icon: Icons.align_horizontal_left,
                          label: 'Left',
                          onTap: () {
                            editorProvider.alignElementsHorizontally('start');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildAlignmentButton(
                          context: context,
                          icon: Icons.align_horizontal_center,
                          label: 'Center',
                          onTap: () {
                            editorProvider.alignElementsHorizontally('center');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildAlignmentButton(
                          context: context,
                          icon: Icons.align_horizontal_right,
                          label: 'Right',
                          onTap: () {
                            editorProvider.alignElementsHorizontally('end');
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Vertical alignment
                  Text(
                    'Vertical Alignment',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildAlignmentButton(
                          context: context,
                          icon: Icons.align_vertical_top,
                          label: 'Top',
                          onTap: () {
                            editorProvider.alignElementsVertically('start');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildAlignmentButton(
                          context: context,
                          icon: Icons.align_vertical_center,
                          label: 'Middle',
                          onTap: () {
                            editorProvider.alignElementsVertically('center');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildAlignmentButton(
                          context: context,
                          icon: Icons.align_vertical_bottom,
                          label: 'Bottom',
                          onTap: () {
                            editorProvider.alignElementsVertically('end');
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Actions section
                  const _SectionHeader(title: 'Actions'),

                  // Delete all selected elements
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.delete),
                          label: const Text('Delete Selected Elements'),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.red,
                          ),
                          onPressed: () {
                            editorProvider.deleteSelectedElements();
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Deselect all button
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.deselect),
                          label: const Text('Deselect All'),
                          onPressed: () {
                            editorProvider.selectElement(null);
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

  Widget _buildSelectionSummary(BuildContext context) {
    // Count element types
    int imageCount = 0;
    int textCount = 0;
    int cameraCount = 0;

    for (final element in selectedElements) {
      switch (element.type) {
        case 'image':
          imageCount++;
          break;
        case 'text':
          textCount++;
          break;
        case 'camera':
          cameraCount++;
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${selectedElements.length} elements selected',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (imageCount > 0) _buildCountRow(Icons.image, 'Images', imageCount),
          if (textCount > 0)
            _buildCountRow(Icons.text_fields, 'Text Elements', textCount),
          if (cameraCount > 0)
            _buildCountRow(Icons.camera_alt, 'Camera Spots', cameraCount),
        ],
      ),
    );
  }

  Widget _buildCountRow(IconData icon, String label, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
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
      ),
    );
  }

  Widget _buildAlignmentButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

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
