import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/layout_editor.dart';
import '../../models/layouts.dart';

class EditorFooter extends StatelessWidget {
  const EditorFooter({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<LayoutEditorProvider>(
      builder: (context, editorProvider, _) {
        final layout = editorProvider.layout;

        if (layout == null) {
          return const SizedBox(height: 0);
        }

        // Count each element type
        final imageCount =
            layout.elements.where((e) => e.type == 'image').length;
        final textCount = layout.elements.where((e) => e.type == 'text').length;
        final cameraCount =
            layout.elements.where((e) => e.type == 'camera').length;
        final selectedCount = editorProvider.selectedElementIds.length;

        // Calculate zoom percentage
        final zoomPercentage = (editorProvider.scale * 100).toStringAsFixed(0);

        return Container(
          height: 28,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),

              // Layout name and dimensions
              Text(
                layout.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${layout.width}×${layout.height}px',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),

              const Spacer(),

              // Element counts section
              if (selectedCount > 0)
                _buildCountBadge(
                  context,
                  'Selected: $selectedCount',
                  selectedCount > 0
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),

              const SizedBox(width: 8),
              _buildCountBadge(context, 'Images: $imageCount', Colors.green),
              const SizedBox(width: 8),
              _buildCountBadge(context, 'Text: $textCount', Colors.orange),
              const SizedBox(width: 8),
              _buildCountBadge(context, 'Camera: $cameraCount', Colors.blue),
              const SizedBox(width: 8),
              _buildCountBadge(
                context,
                'Total: ${layout.elements.length}',
                Colors.grey,
              ),

              const SizedBox(width: 12),
              const VerticalDivider(width: 1),
              const SizedBox(width: 12),

              // Zoom indicator
              const Icon(Icons.zoom_in, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text('$zoomPercentage%', style: const TextStyle(fontSize: 12)),

              const SizedBox(width: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCountBadge(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
