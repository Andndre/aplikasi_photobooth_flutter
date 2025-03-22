import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/layouts.dart';
import '../../providers/layout_editor.dart';
import 'layer_item.dart';

class LayersSidebar extends StatelessWidget {
  const LayersSidebar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use Consumer for efficient rebuilds
    return Consumer<LayoutEditorProvider>(
      builder: (context, editorProvider, _) {
        final layout = editorProvider.layout;

        if (layout == null) {
          return const Center(child: Text('No layout loaded'));
        }

        // Reversed list for correct z-index display (top item = front)
        final List<LayoutElement> reversedElements =
            layout.elements.reversed.toList();

        return Container(
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: Theme.of(context).dividerColor),
            ),
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
                    const Icon(Icons.layers),
                    const SizedBox(width: 8),
                    Text(
                      'Layers',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Text(
                      '${layout.elements.length} items',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              // Search box (optional)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search layers...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  // Implement search functionality here
                ),
              ),

              // Layer type filters (optional)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    _buildFilterChip(context, 'All', true, () {}),
                    _buildFilterChip(context, 'Image', false, () {}),
                    _buildFilterChip(context, 'Text', false, () {}),
                    _buildFilterChip(context, 'Camera', false, () {}),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              const Divider(height: 1),

              // Layers list with ReorderableListView for drag reordering
              Expanded(
                child: ReorderableListView.builder(
                  buildDefaultDragHandles:
                      false, // We'll add custom drag handles
                  padding: EdgeInsets.zero,
                  itemCount: reversedElements.length,
                  itemBuilder: (context, index) {
                    final element = reversedElements[index];
                    final isSelected =
                        editorProvider.selectedElement?.id == element.id;

                    // Fix: Use ChangeNotifierProvider.value to provide access during reordering
                    return ChangeNotifierProvider<LayoutEditorProvider>.value(
                      key: ValueKey(element.id),
                      value: editorProvider,
                      child: ReorderableDragStartListener(
                        index: index,
                        enabled:
                            !element
                                .isLocked, // Disable drag for locked elements
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            vertical: 1.0,
                            horizontal: 4.0,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                        .withOpacity(0.5)
                                    : null,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: LayerItem(element: element),
                        ),
                      ),
                    );
                  },
                  onReorder: (oldIndex, newIndex) {
                    // Handle the reordering of layers
                    // Note: ReorderableListView indexes are relative to the visible list
                    if (oldIndex < newIndex) {
                      // When moving down, the item is inserted after the destination
                      newIndex -= 1;
                    }

                    // Convert the reversed list index to the actual order in elements list
                    final actualOldIndex =
                        layout.elements.length - 1 - oldIndex;
                    final actualNewIndex =
                        layout.elements.length - 1 - newIndex;

                    // Call the provider to reorder elements
                    editorProvider.reorderElements(
                      actualOldIndex,
                      actualNewIndex,
                    );
                  },
                ),
              ),

              // Bottom action bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  border: Border(
                    top: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                child: Row(
                  children: [
                    Tooltip(
                      message: 'Show/Hide All',
                      child: IconButton(
                        icon: const Icon(Icons.visibility, size: 20),
                        onPressed: () {
                          // Toggle visibility of all elements
                          editorProvider.toggleAllElementsVisibility();
                        },
                      ),
                    ),
                    Tooltip(
                      message: 'Lock/Unlock All',
                      child: IconButton(
                        icon: const Icon(Icons.lock_outline, size: 20),
                        onPressed: () {
                          // Toggle lock of all elements
                          editorProvider.toggleAllElementsLock();
                        },
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton(
                      onPressed: () {
                        // Group selected elements
                        // (Advanced feature - could be implemented later)
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text(
                        'Group',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 12)),
        selected: isSelected,
        onSelected: (value) => onTap(),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
