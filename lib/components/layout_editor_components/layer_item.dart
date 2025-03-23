import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/layouts.dart';
import '../../providers/layout_editor.dart';

class LayerItem extends StatelessWidget {
  final LayoutElement element;
  final bool isSelected;

  const LayerItem({Key? key, required this.element, this.isSelected = false})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Fix: Use listen: false to avoid rebuilds during drag operations
    final editorProvider = Provider.of<LayoutEditorProvider>(
      context,
      listen: false,
    );
    // Don't redefine isSelected since it's passed as a parameter now
    // Just use the parameter directly

    String elementName;
    IconData elementIcon;
    bool isGroup = false;

    switch (element.type) {
      case 'image':
        final imageElement = element as ImageElement;
        // Extract just the filename instead of the full path
        final filename = imageElement.path.split('/').last.split('\\').last;
        elementName = filename;
        elementIcon = Icons.image;
        break;
      case 'text':
        final textElement = element as TextElement;
        elementName =
            textElement.text.length > 15
                ? '${textElement.text.substring(0, 10)}...'
                : textElement.text;
        elementIcon = Icons.text_fields;
        break;
      case 'camera':
        final cameraElement = element as CameraElement;
        elementName = cameraElement.label;
        elementIcon = Icons.camera_alt;
        break;
      case 'group':
        final groupElement = element as GroupElement;
        elementName = groupElement.name;
        elementIcon = Icons.folder;
        isGroup = true;
        break;
      default:
        elementName = 'Unknown element';
        elementIcon = Icons.help;
    }

    // Add expand/collapse functionality for groups
    final bool isExpanded = editorProvider.isGroupExpanded(element.id);

    // Wrap the ListTile with a GestureDetector for right-click context menu
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onSecondaryTap: () {
            // Show context menu on right-click
            _showContextMenu(context, editorProvider);
          },
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.only(
              left: isGroup ? 4 : 8,
              right: 8,
              top: 0,
              bottom: 0,
            ),
            selected: isSelected,
            selectedTileColor: Colors.transparent,
            // Add a drag handle at the start
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isGroup)
                  IconButton(
                    icon: Icon(
                      isExpanded ? Icons.expand_more : Icons.chevron_right,
                      size: 16,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    onPressed: () {
                      editorProvider.toggleGroupExpansion(element.id);
                    },
                  ),
                if (!element.isLocked)
                  Icon(
                    Icons.drag_handle,
                    size: 16,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.5),
                  ),
                const SizedBox(width: 4),
                Icon(
                  elementIcon,
                  color:
                      element.isVisible
                          ? (isSelected
                              ? Theme.of(context).colorScheme.primary
                              : null)
                          : Colors.grey,
                ),
              ],
            ),
            title: Text(
              elementName,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color:
                    isSelected
                        ? Theme.of(context).colorScheme.primary
                        : (!element.isVisible ? Colors.grey : null),
                decoration:
                    !element.isVisible ? TextDecoration.lineThrough : null,
              ),
            ),
            // Keep visibility and lock toggles, but remove checkbox for multi-select
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    element.isVisible ? Icons.visibility : Icons.visibility_off,
                    size: 18,
                  ),
                  tooltip: element.isVisible ? 'Hide' : 'Show',
                  onPressed: () {
                    editorProvider.toggleElementVisibility(element.id);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    element.isLocked ? Icons.lock : Icons.lock_open,
                    size: 18,
                  ),
                  tooltip: element.isLocked ? 'Unlock' : 'Lock',
                  onPressed: () {
                    editorProvider.toggleElementLock(element.id);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                ),
              ],
            ),
            // Layer sidebar uses ctrl modifier for multi-selection
            onTap: () {
              // Check if Ctrl key is pressed for multi-select
              final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;

              editorProvider.selectElement(
                element,
                addToSelection: isCtrlPressed,
              );
            },
            onLongPress: () {
              // Show context menu on long press for mobile support
              _showContextMenu(context, editorProvider);
            },
          ),
        ),

        // Show children if this is an expanded group
        if (isGroup && isExpanded)
          _buildGroupChildren(context, element as GroupElement, editorProvider),
      ],
    );
  }

  // New method to build group children list
  Widget _buildGroupChildren(
    BuildContext context,
    GroupElement group,
    LayoutEditorProvider editorProvider,
  ) {
    final childElements = editorProvider.getGroupChildren(group.id);

    return Container(
      margin: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children:
            childElements.map((child) {
              return LayerItem(
                element: child,
                isSelected: editorProvider.isElementSelected(child.id),
              );
            }).toList(),
      ),
    );
  }

  // Method to show context menu - updated to include group options
  void _showContextMenu(
    BuildContext context,
    LayoutEditorProvider editorProvider,
  ) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    // Add group-specific menu items
    final isGroup = element.type == 'group';

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + size.height,
        position.dx + size.width,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'duplicate',
          child: Row(
            children: [
              Icon(Icons.copy, size: 18),
              const SizedBox(width: 8),
              const Text('Duplicate'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'bringToFront',
          child: Row(
            children: [
              Icon(Icons.vertical_align_top, size: 18),
              const SizedBox(width: 8),
              const Text('Bring to Front'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'sendToBack',
          child: Row(
            children: [
              Icon(Icons.vertical_align_bottom, size: 18),
              const SizedBox(width: 8),
              const Text('Send to Back'),
            ],
          ),
        ),
        if (isGroup)
          PopupMenuItem(
            value: 'ungroup',
            child: Row(
              children: [
                Icon(Icons.group_remove, size: 18),
                const SizedBox(width: 8),
                const Text('Ungroup'),
              ],
            ),
          ),
        if (isGroup)
          PopupMenuItem(
            value: 'renameGroup',
            child: Row(
              children: [
                Icon(Icons.edit, size: 18),
                const SizedBox(width: 8),
                const Text('Rename Group'),
              ],
            ),
          ),
        if (element.type == 'text')
          PopupMenuItem(
            value: 'editText',
            child: Row(
              children: [
                Icon(Icons.text_fields, size: 18),
                const SizedBox(width: 8),
                const Text('Edit Text'),
              ],
            ),
          ),
        if (element.type == 'image')
          PopupMenuItem(
            value: 'replaceImage',
            child: Row(
              children: [
                Icon(Icons.image, size: 18),
                const SizedBox(width: 8),
                const Text('Replace Image'),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete,
                size: 18,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 8),
              const Text('Delete'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;

      switch (value) {
        case 'delete':
          editorProvider.deleteElement(element.id);
          break;
        case 'duplicate':
          editorProvider.copyElement(element.id);
          editorProvider.pasteElement();
          break;
        case 'bringToFront':
          editorProvider.bringToFront(element.id);
          break;
        case 'sendToBack':
          editorProvider.sendToBack(element.id);
          break;
        case 'ungroup':
          editorProvider.ungroupSelectedElements();
          break;
        case 'renameGroup':
          _renameGroup(context, editorProvider, element as GroupElement);
          break;
        case 'editText':
          _editTextElement(context, editorProvider, element as TextElement);
          break;
        case 'replaceImage':
          _replaceImage(context, editorProvider, element as ImageElement);
          break;
      }
    });
  }

  // Add a method to handle group renaming
  void _renameGroup(
    BuildContext context,
    LayoutEditorProvider editorProvider,
    GroupElement group,
  ) {
    final TextEditingController nameController = TextEditingController(
      text: group.name,
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Rename Group'),
            content: TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  editorProvider.updateGroupName(group.id, nameController.text);
                  Navigator.of(context).pop();
                },
                child: const Text('Rename'),
              ),
            ],
          ),
    );
  }

  // Existing _showLayerOptions method can be removed

  void _editTextElement(
    BuildContext context,
    LayoutEditorProvider editorProvider,
    TextElement element,
  ) {
    final TextEditingController textController = TextEditingController(
      text: element.text,
    );

    // Simple dialog to edit text content
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Text'),
            content: TextField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: 'Text Content',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  editorProvider.updateTextElement(
                    element.id,
                    text: textController.text,
                  );
                  Navigator.of(context).pop();
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  void _replaceImage(
    BuildContext context,
    LayoutEditorProvider editorProvider,
    ImageElement element,
  ) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null && result.files.single.path != null) {
      editorProvider.updateImageElement(
        element.id,
        path: result.files.single.path!,
      );
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
