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

    // Count of each element type
    final int imageCount =
        selectedElements.where((e) => e.type == 'image').length;
    final int textCount =
        selectedElements.where((e) => e.type == 'text').length;
    final int cameraCount =
        selectedElements.where((e) => e.type == 'camera').length;

    // Check if all elements have the same type
    final bool allSameType = selectedElements.every(
      (e) => e.type == selectedElements.first.type,
    );

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
                const Icon(Icons.select_all),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Multiple Selection (${selectedElements.length} items)',
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Selection details
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSelectionSummary(imageCount, textCount, cameraCount),
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
                  // Alignment section
                  const _SectionHeader(title: 'Alignment'),

                  // Horizontal alignment controls
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Horizontal',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildAlignmentButton(
                                context: context,
                                icon: Icons.align_horizontal_left,
                                label: 'Left',
                                onTap:
                                    () => editorProvider
                                        .alignElementsHorizontally('start'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildAlignmentButton(
                                context: context,
                                icon: Icons.align_horizontal_center,
                                label: 'Center',
                                onTap:
                                    () => editorProvider
                                        .alignElementsHorizontally('center'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildAlignmentButton(
                                context: context,
                                icon: Icons.align_horizontal_right,
                                label: 'Right',
                                onTap:
                                    () => editorProvider
                                        .alignElementsHorizontally('end'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Vertical alignment controls
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Vertical', style: TextStyle(fontSize: 14)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildAlignmentButton(
                                context: context,
                                icon: Icons.vertical_align_top,
                                label: 'Top',
                                onTap:
                                    () => editorProvider
                                        .alignElementsVertically('start'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildAlignmentButton(
                                context: context,
                                icon: Icons.vertical_align_center,
                                label: 'Middle',
                                onTap:
                                    () => editorProvider
                                        .alignElementsVertically('center'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildAlignmentButton(
                                context: context,
                                icon: Icons.vertical_align_bottom,
                                label: 'Bottom',
                                onTap:
                                    () => editorProvider
                                        .alignElementsVertically('end'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Distribution section (only shown when 3+ elements selected)
                  if (selectedElements.length >= 3)
                    _buildDistributionSection(context, editorProvider),

                  const SizedBox(height: 16),
                  const Divider(),

                  // Bulk actions section
                  const _SectionHeader(title: 'Bulk Actions'),

                  // Sizing options
                  if (allSameType)
                    _buildSizeMatchingSection(context, editorProvider),

                  // Visibility and lock toggles
                  _buildBulkVisibilityAndLockControls(context, editorProvider),

                  const SizedBox(height: 16),

                  // Type-specific properties if all elements are the same type
                  if (allSameType && textCount > 0)
                    _buildBulkTextProperties(context, editorProvider),

                  if (allSameType && imageCount > 0)
                    _buildBulkImageProperties(context, editorProvider),

                  // Deletion section
                  const SizedBox(height: 16),
                  const Divider(),
                  const _SectionHeader(title: 'Actions'),

                  // Delete button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.errorContainer,
                        foregroundColor:
                            Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: Text(
                        'Delete Selected (${selectedElements.length})',
                      ),
                      onPressed: () {
                        editorProvider.deleteSelectedElements();
                      },
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

  Widget _buildSelectionSummary(
    int imageCount,
    int textCount,
    int cameraCount,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selection Summary',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (imageCount > 0)
            _buildTypeSummaryRow(Icons.image, 'Images', imageCount),
          if (textCount > 0)
            _buildTypeSummaryRow(Icons.text_fields, 'Text', textCount),
          if (cameraCount > 0)
            _buildTypeSummaryRow(Icons.camera_alt, 'Camera', cameraCount),
        ],
      ),
    );
  }

  Widget _buildTypeSummaryRow(IconData icon, String type, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Text(type),
          const Spacer(),
          Text(
            count.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionSection(
    BuildContext context,
    LayoutEditorProvider editorProvider,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'Distribution'),
          Row(
            children: [
              Expanded(
                child: _buildAlignmentButton(
                  context: context,
                  icon: Icons.space_bar,
                  label: 'Distribute\nHorizontally',
                  onTap: () {
                    // Implement horizontal distribution logic
                    _distributeElements(editorProvider, true);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAlignmentButton(
                  context: context,
                  icon: Icons.space_bar,
                  iconRotation: 90, // Rotate icon for vertical
                  label: 'Distribute\nVertically',
                  onTap: () {
                    // Implement vertical distribution logic
                    _distributeElements(editorProvider, false);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _distributeElements(
    LayoutEditorProvider editorProvider,
    bool horizontal,
  ) {
    if (selectedElements.length < 3) return;

    // Sort elements by position
    final sortedElements = [...selectedElements];
    if (horizontal) {
      sortedElements.sort((a, b) => a.x.compareTo(b.x));
    } else {
      sortedElements.sort((a, b) => a.y.compareTo(b.y));
    }

    // Calculate total available space
    double startPos, endPos, totalSize = 0;

    if (horizontal) {
      startPos = sortedElements.first.x;
      endPos = sortedElements.last.x + sortedElements.last.width;
      // Calculate total element width
      for (var element in sortedElements) {
        totalSize += element.width;
      }
    } else {
      startPos = sortedElements.first.y;
      endPos = sortedElements.last.y + sortedElements.last.height;
      // Calculate total element height
      for (var element in sortedElements) {
        totalSize += element.height;
      }
    }

    // Calculate spacing
    final availableSpace = endPos - startPos;
    final spacing = (availableSpace - totalSize) / (sortedElements.length - 1);

    // Apply distribution
    double currentPos = startPos;
    for (int i = 0; i < sortedElements.length; i++) {
      final element = sortedElements[i];

      if (horizontal) {
        if (i > 0) {
          editorProvider.updateElementPosition(
            element.id,
            Offset(currentPos, element.y),
          );
        }
        currentPos += element.width + spacing;
      } else {
        if (i > 0) {
          editorProvider.updateElementPosition(
            element.id,
            Offset(element.x, currentPos),
          );
        }
        currentPos += element.height + spacing;
      }
    }
  }

  Widget _buildSizeMatchingSection(
    BuildContext context,
    LayoutEditorProvider editorProvider,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Match Size', style: TextStyle(fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.width_normal, size: 18),
                  label: const Text('Match Width'),
                  onPressed: () => _matchDimension(editorProvider, true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.height, size: 18),
                  label: const Text('Match Height'),
                  onPressed: () => _matchDimension(editorProvider, false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.aspect_ratio, size: 18),
              label: const Text('Match Both Dimensions'),
              onPressed: () {
                // First match width, then height
                _matchDimension(editorProvider, true);
                _matchDimension(editorProvider, false);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _matchDimension(LayoutEditorProvider editorProvider, bool isWidth) {
    if (selectedElements.isEmpty || editorProvider.selectedElement == null)
      return;

    // Use the primary selected element as reference
    final reference = editorProvider.selectedElement!;
    final targetValue = isWidth ? reference.width : reference.height;

    // Apply to all selected elements except the reference
    for (final element in selectedElements) {
      if (element.id != reference.id) {
        if (isWidth) {
          editorProvider.updateElementSize(
            element.id,
            Size(targetValue, element.height),
          );
        } else {
          editorProvider.updateElementSize(
            element.id,
            Size(element.width, targetValue),
          );
        }
      }
    }
  }

  Widget _buildBulkVisibilityAndLockControls(
    BuildContext context,
    LayoutEditorProvider editorProvider,
  ) {
    // Count visible and locked elements
    final visibleCount = selectedElements.where((e) => e.isVisible).length;
    final lockedCount = selectedElements.where((e) => e.isLocked).length;

    // Determine the majority state to toggle
    final mostlyVisible = visibleCount > selectedElements.length / 2;
    final mostlyLocked = lockedCount > selectedElements.length / 2;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: Icon(
                mostlyVisible ? Icons.visibility_off : Icons.visibility,
              ),
              label: Text(mostlyVisible ? 'Hide All' : 'Show All'),
              onPressed: () {
                // Toggle visibility for all selected elements
                for (final element in selectedElements) {
                  editorProvider.toggleElementVisibility(element.id);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              icon: Icon(mostlyLocked ? Icons.lock_open : Icons.lock),
              label: Text(mostlyLocked ? 'Unlock All' : 'Lock All'),
              onPressed: () {
                // Toggle lock for all selected elements
                for (final element in selectedElements) {
                  editorProvider.toggleElementLock(element.id);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkTextProperties(
    BuildContext context,
    LayoutEditorProvider editorProvider,
  ) {
    // All elements are text elements at this point
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Text Properties'),

        // Font style bulk controls
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.format_bold),
                label: const Text('Toggle Bold'),
                onPressed: () {
                  _toggleTextStyle(editorProvider, isBold: true);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.format_italic),
                label: const Text('Toggle Italic'),
                onPressed: () {
                  _toggleTextStyle(editorProvider, isBold: false);
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Font size controls
        const Text('Adjust Font Size', style: TextStyle(fontSize: 14)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.text_decrease),
                label: const Text('Smaller (-2)'),
                onPressed: () {
                  _adjustFontSize(editorProvider, -2);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.text_increase),
                label: const Text('Larger (+2)'),
                onPressed: () {
                  _adjustFontSize(editorProvider, 2);
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Text alignment controls
        const Text('Alignment', style: TextStyle(fontSize: 14)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildAlignmentButton(
                context: context,
                icon: Icons.format_align_left,
                label: 'Left',
                onTap: () => _setTextAlignment(editorProvider, 'left'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildAlignmentButton(
                context: context,
                icon: Icons.format_align_center,
                label: 'Center',
                onTap: () => _setTextAlignment(editorProvider, 'center'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildAlignmentButton(
                context: context,
                icon: Icons.format_align_right,
                label: 'Right',
                onTap: () => _setTextAlignment(editorProvider, 'right'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _toggleTextStyle(
    LayoutEditorProvider editorProvider, {
    required bool isBold,
  }) {
    // Count how many elements have the style
    int count = 0;
    for (final element in selectedElements) {
      if (element.type == 'text') {
        final textElement = element as TextElement;
        if (isBold ? textElement.isBold : textElement.isItalic) {
          count++;
        }
      }
    }

    // Determine if we should enable or disable the style
    final majority = count > selectedElements.length / 2;
    final newValue = !majority;

    // Apply to all text elements
    for (final element in selectedElements) {
      if (element.type == 'text') {
        editorProvider.updateTextElement(
          element.id,
          isBold: isBold ? newValue : null,
          isItalic: isBold ? null : newValue,
        );
      }
    }
  }

  void _adjustFontSize(LayoutEditorProvider editorProvider, double adjustment) {
    for (final element in selectedElements) {
      if (element.type == 'text') {
        final textElement = element as TextElement;
        // Ensure font size doesn't go below 8 or above 72
        final newSize = (textElement.fontSize + adjustment).clamp(8.0, 72.0);
        editorProvider.updateTextElement(element.id, fontSize: newSize);
      }
    }
  }

  void _setTextAlignment(
    LayoutEditorProvider editorProvider,
    String alignment,
  ) {
    String targetAlignment;

    // Map simplified alignment to actual alignment values
    switch (alignment) {
      case 'left':
        targetAlignment = 'centerLeft';
        break;
      case 'center':
        targetAlignment = 'center';
        break;
      case 'right':
        targetAlignment = 'centerRight';
        break;
      default:
        targetAlignment = 'center';
    }

    // Apply to all text elements
    for (final element in selectedElements) {
      if (element.type == 'text') {
        editorProvider.updateTextElement(
          element.id,
          alignment: targetAlignment,
        );
      }
    }
  }

  Widget _buildBulkImageProperties(
    BuildContext context,
    LayoutEditorProvider editorProvider,
  ) {
    // Check if all image elements have aspect ratio locked
    final lockedCount =
        selectedElements
            .where(
              (e) => e.type == 'image' && (e as ImageElement).aspectRatioLocked,
            )
            .length;

    final mostlyLocked = lockedCount > selectedElements.length / 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Image Properties'),

        // Aspect ratio control
        OutlinedButton.icon(
          icon: Icon(
            mostlyLocked ? Icons.lock_open_outlined : Icons.lock_outline,
          ),
          label: Text(
            mostlyLocked ? 'Unlock Aspect Ratio' : 'Lock Aspect Ratio',
          ),
          onPressed: () {
            for (final element in selectedElements) {
              if (element.type == 'image') {
                editorProvider.updateImageElement(
                  element.id,
                  aspectRatioLocked: !mostlyLocked,
                );
              }
            }
          },
        ),

        const SizedBox(height: 16),

        // Opacity controls
        const Text('Adjust Opacity', style: TextStyle(fontSize: 14)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.opacity),
                label: const Text('Decrease (-0.1)'),
                onPressed: () {
                  _adjustImageOpacity(editorProvider, -0.1);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.opacity),
                label: const Text('Increase (+0.1)'),
                onPressed: () {
                  _adjustImageOpacity(editorProvider, 0.1);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _adjustImageOpacity(
    LayoutEditorProvider editorProvider,
    double adjustment,
  ) {
    for (final element in selectedElements) {
      if (element.type == 'image') {
        final imageElement = element as ImageElement;
        // Ensure opacity stays between 0.0 and 1.0
        final newOpacity = (imageElement.opacity + adjustment).clamp(0.0, 1.0);
        editorProvider.updateImageElement(element.id, opacity: newOpacity);
      }
    }
  }

  Widget _buildAlignmentButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    double iconRotation = 0,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.rotate(
              angle: iconRotation * 3.14159 / 180,
              child: Icon(icon, size: 20),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
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
