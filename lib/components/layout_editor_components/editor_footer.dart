import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/layout_editor.dart';

class EditorFooter extends StatelessWidget {
  const EditorFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final editorProvider = Provider.of<LayoutEditorProvider>(context);
    final layout = editorProvider.layout;

    if (layout == null) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          // Canvas dimensions
          Text(
            'Canvas: ${layout.width} × ${layout.height}px',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(width: 16),

          // Selected element info
          if (editorProvider.selectedElement != null)
            Text(
              'Selected: ${_getElementTypeLabel(editorProvider.selectedElement!.type)}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),

          // Multiple selection info
          if (editorProvider.hasMultipleElementsSelected)
            Text(
              '(${editorProvider.selectedElementIds.length} items)',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),

          const Spacer(),

          // Zoom level display
          Text(
            '${(editorProvider.scale * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),

          // Toggle grid button (optional in footer)
          IconButton(
            icon: Icon(
              editorProvider.showGrid ? Icons.grid_on : Icons.grid_off,
              size: 16,
            ),
            tooltip: editorProvider.showGrid ? 'Hide Grid' : 'Show Grid',
            onPressed: editorProvider.toggleGrid,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
          ),
        ],
      ),
    );
  }

  String _getElementTypeLabel(String type) {
    switch (type) {
      case 'image':
        return 'Image';
      case 'text':
        return 'Text';
      case 'camera':
        return 'Camera';
      case 'group':
        return 'Group';
      default:
        return 'Element';
    }
  }
}
