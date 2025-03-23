import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart'; // Add this import for HardwareKeyboard
import '../../models/layouts.dart';
import '../../providers/layout_editor.dart';
import 'layer_item.dart';

class LayersSidebar extends StatefulWidget {
  const LayersSidebar({Key? key}) : super(key: key);

  @override
  State<LayersSidebar> createState() => _LayersSidebarState();
}

class _LayersSidebarState extends State<LayersSidebar> {
  // Add state variables for filtering and searching
  String _activeFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use Consumer for efficient rebuilds
    return Consumer<LayoutEditorProvider>(
      builder: (context, editorProvider, _) {
        final layout = editorProvider.layout;

        if (layout == null) {
          return const Center(child: Text('No layout loaded'));
        }

        // Apply filtering and searching to elements
        List<LayoutElement> filteredElements = layout.elements;

        // Apply type filter if not "All"
        if (_activeFilter != 'All') {
          final filterType = _activeFilter.toLowerCase();
          filteredElements =
              filteredElements.where((e) => e.type == filterType).toList();
        }

        // Apply search filter if search query is not empty
        if (_searchQuery.isNotEmpty) {
          filteredElements =
              filteredElements.where((element) {
                switch (element.type) {
                  case 'image':
                    final imageEl = element as ImageElement;
                    final filename =
                        imageEl.path.split('/').last.split('\\').last;
                    return filename.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    );
                  case 'text':
                    final textEl = element as TextElement;
                    return textEl.text.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    );
                  case 'camera':
                    final cameraEl = element as CameraElement;
                    return cameraEl.label.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    );
                  default:
                    return false;
                }
              }).toList();
        }

        // Reversed list for correct z-index display (top item = front)
        final List<LayoutElement> reversedElements =
            filteredElements.reversed.toList();

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
                      '${reversedElements.length} of ${layout.elements.length} items',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              // Search box
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search layers...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon:
                        _searchQuery.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                            )
                            : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),

              // Layer type filters
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    _buildFilterChip(
                      context,
                      'All',
                      _activeFilter == 'All',
                      () {
                        setState(() {
                          _activeFilter = 'All';
                        });
                      },
                    ),
                    _buildFilterChip(
                      context,
                      'Image',
                      _activeFilter == 'Image',
                      () {
                        setState(() {
                          _activeFilter = 'Image';
                        });
                      },
                    ),
                    _buildFilterChip(
                      context,
                      'Text',
                      _activeFilter == 'Text',
                      () {
                        setState(() {
                          _activeFilter = 'Text';
                        });
                      },
                    ),
                    _buildFilterChip(
                      context,
                      'Camera',
                      _activeFilter == 'Camera',
                      () {
                        setState(() {
                          _activeFilter = 'Camera';
                        });
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              const Divider(height: 1),

              // Empty state message when no elements match filters
              if (reversedElements.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.filter_list_off,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No layers match your filters',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Clear filters'),
                          onPressed: () {
                            setState(() {
                              _activeFilter = 'All';
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),

              // Layers list with ReorderableListView for drag reordering
              if (reversedElements.isNotEmpty)
                Expanded(
                  child: ReorderableListView.builder(
                    buildDefaultDragHandles:
                        false, // We'll add custom drag handles
                    padding: EdgeInsets.zero,
                    itemCount: reversedElements.length,
                    itemBuilder: (context, index) {
                      final element = reversedElements[index];
                      final isSelected = editorProvider.isElementSelected(
                        element.id,
                      );

                      // Fix: Use ChangeNotifierProvider.value to provide access during reordering
                      return ChangeNotifierProvider<LayoutEditorProvider>.value(
                        key: ValueKey(element.id),
                        value: editorProvider,
                        child: ReorderableDragStartListener(
                          index: index,
                          enabled:
                              !element
                                  .isLocked, // Disable drag for locked elements
                          child: GestureDetector(
                            // Add behavior for Ctrl+click or Shift+click multi-select
                            onTap: () {
                              // Check if Ctrl or Shift key is pressed for multi-select
                              final isMultiSelectModifier =
                                  HardwareKeyboard.instance.isControlPressed ||
                                  HardwareKeyboard.instance.isShiftPressed;

                              editorProvider.selectElement(
                                element,
                                addToSelection: isMultiSelectModifier,
                              );
                            },
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
                              child: LayerItem(
                                element: element,
                                isSelected: isSelected,
                              ),
                            ),
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

                      // First, we need to get the actual elements from the filtered list
                      final sourceElement = reversedElements[oldIndex];
                      final targetElement =
                          reversedElements[newIndex < reversedElements.length
                              ? newIndex
                              : reversedElements.length - 1];

                      // Now find their indices in the original list
                      final actualOldIndex = layout.elements.indexWhere(
                        (e) => e.id == sourceElement.id,
                      );
                      final actualNewIndex = layout.elements.indexWhere(
                        (e) => e.id == targetElement.id,
                      );

                      // Call the provider to reorder elements
                      if (actualOldIndex != -1 && actualNewIndex != -1) {
                        // Adjust the target index based on direction
                        final adjustedNewIndex =
                            oldIndex < newIndex
                                ? actualNewIndex
                                : actualNewIndex + 1;
                        editorProvider.reorderElements(
                          actualOldIndex,
                          adjustedNewIndex > actualOldIndex
                              ? adjustedNewIndex - 1
                              : adjustedNewIndex,
                        );
                      }
                    },
                  ),
                ),

              // Bottom action bar with added Select All button
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
                    Tooltip(
                      message: 'Select All',
                      child: IconButton(
                        icon: const Icon(Icons.select_all, size: 20),
                        onPressed: () {
                          editorProvider.selectAllElements();
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
        onSelected: (value) {
          if (value) {
            onTap();
          }
        },
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
