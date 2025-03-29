import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photobooth/models/renderables/camera_element.dart';
import 'package:photobooth/models/renderables/image_element.dart';
import 'package:photobooth/models/renderables/layout_element.dart';
import 'package:photobooth/models/renderables/text_element.dart';
import 'package:photobooth/providers/layout_editor_provider.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

class LayerItem extends StatelessWidget {
  final LayoutElement element;
  final bool isSelected;

  const LayerItem({super.key, required this.element, this.isSelected = false});

  @override
  Widget build(BuildContext context) {
    // Use listen: true to ensure the widget rebuilds when selection changes
    final editorProvider = Provider.of<LayoutEditorProvider>(
      context,
      listen: true,
    );

    // Always get the current selection state directly from the provider
    // This ensures we have the most up-to-date selection status
    final isCurrentlySelected = editorProvider.isElementSelected(element.id);

    String elementName;
    IconData elementIcon;

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
      default:
        elementName = 'Unknown element';
        elementIcon = Icons.help;
    }

    // Define highlight colors based on selection state
    final Color selectedBgColor = Theme.of(
      context,
    ).colorScheme.primaryContainer.withValues(alpha: 0.7);
    final Color defaultBgColor = Colors.transparent;
    final Color selectedTextColor = Theme.of(context).colorScheme.primary;
    // final Color defaultTextColor = element.isVisible ? null : Colors.grey;

    // Wrap the ListTile with a GestureDetector for right-click context menu
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          // Apply background color based on selection state - use the current selection state
          color: isCurrentlySelected ? selectedBgColor : defaultBgColor,
          child: GestureDetector(
            onSecondaryTap: () {
              // Show context menu on right-click
              _showContextMenu(context, editorProvider);
            },
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.only(
                left: 8,
                right: 8,
                top: 0,
                bottom: 0,
              ),
              // Don't use ListTile's selected property as we're handling highlighting ourselves
              selected: false,
              selectedTileColor: Colors.transparent,
              // Add a drag handle at the start
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!element.isLocked)
                    Icon(
                      Icons.drag_handle,
                      size: 16,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    elementIcon,
                    color:
                        element.isVisible
                            ? (isCurrentlySelected ? selectedTextColor : null)
                            : Colors.grey,
                  ),
                ],
              ),
              title: Text(
                elementName,
                style: TextStyle(
                  // Remove the fontWeight condition - no longer bold when selected
                  fontWeight: FontWeight.normal,
                  color:
                      isCurrentlySelected
                          ? selectedTextColor
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
                      element.isVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
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
                final isCtrlPressed =
                    HardwareKeyboard.instance.isControlPressed;

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
        ),
      ],
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
        case 'editText':
          {
            if (context.mounted) {
              _editTextElement(context, editorProvider, element as TextElement);
            }
            break;
          }
        case 'replaceImage':
          {
            if (context.mounted) {
              _replaceImage(context, editorProvider, element as ImageElement);
            }
            break;
          }
      }
    });
  }

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
}
