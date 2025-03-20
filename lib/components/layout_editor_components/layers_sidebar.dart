import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../providers/layout_editor.dart';
import 'layer_item.dart';

class LayersSidebar extends StatelessWidget {
  const LayersSidebar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final editorProvider = Provider.of<LayoutEditorProvider>(context);
    final layout = editorProvider.layout;

    if (layout == null) {
      return const Center(child: Text('No layout loaded'));
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sidebar header
          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Layers', style: Theme.of(context).textTheme.titleMedium),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.color_lens, size: 20),
                      tooltip: 'Change background color',
                      onPressed:
                          () => _showColorPicker(context, editorProvider),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 30,
                        minHeight: 30,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.add, size: 20),
                      tooltip: 'Add element',
                      onPressed:
                          () => _showAddElementMenu(context, editorProvider),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 30,
                        minHeight: 30,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Layers list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: layout.elements.length,
              itemBuilder: (context, index) {
                // Display elements in reverse order so top-most element is at the top
                final element =
                    layout.elements[layout.elements.length - 1 - index];
                return LayerItem(element: element);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showColorPicker(
    BuildContext context,
    LayoutEditorProvider editorProvider,
  ) {
    final layout = editorProvider.layout;
    if (layout == null) return;

    Color currentColor = _hexToColor(layout.backgroundColor);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Select Background Color'),
            content: SingleChildScrollView(
              child: ColorPicker(
                pickerColor: currentColor,
                onColorChanged: (color) {
                  currentColor = color;
                },
                pickerAreaHeightPercent: 0.8,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  editorProvider.updateLayoutBackground(
                    '#${currentColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
                  );
                  Navigator.of(context).pop();
                },
                child: const Text('Apply'),
              ),
            ],
          ),
    );
  }

  void _showAddElementMenu(
    BuildContext context,
    LayoutEditorProvider editorProvider,
  ) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(const Offset(0, 0), ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    showMenu(
      context: context,
      position: position,
      items: [
        PopupMenuItem(
          child: const Text('Add Image'),
          onTap: () async {
            // Allow time for the menu to close
            await Future.delayed(Duration.zero);
            if (context.mounted) {
              _addImage(context, editorProvider);
            }
          },
        ),
        PopupMenuItem(
          child: const Text('Add Text'),
          onTap: () {
            editorProvider.addTextElement();
          },
        ),
        PopupMenuItem(
          child: const Text('Add Camera Spot'),
          onTap: () {
            editorProvider.addCameraElement();
          },
        ),
      ],
    );
  }

  Future<void> _addImage(
    BuildContext context,
    LayoutEditorProvider editorProvider,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null &&
        result.files.isNotEmpty &&
        result.files.first.path != null) {
      editorProvider.addImageElement(result.files.first.path!);
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
