import 'package:flutter/material.dart';
import 'package:photobooth/providers/layout_editor_provider.dart';
import 'package:provider/provider.dart';

class ZoomControls extends StatelessWidget {
  const ZoomControls({super.key});

  @override
  Widget build(BuildContext context) {
    final editorProvider = Provider.of<LayoutEditorProvider>(context);
    final layout = editorProvider.layout;

    // Get actual scale from transformation matrix for accuracy
    final actualScale =
        editorProvider.transformationController.value.getMaxScaleOnAxis();
    final zoomPercentage = (actualScale * 100).toStringAsFixed(0);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Zoom in',
            onPressed: () {
              editorProvider.zoom(1.2);
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              '$zoomPercentage%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove),
            tooltip: 'Zoom out',
            onPressed: () {
              editorProvider.zoom(1 / 1.2); // More moderate zoom out factor
            },
          ),
          const Divider(height: 1),
          IconButton(
            icon: const Icon(Icons.fit_screen),
            tooltip: 'Fit to screen',
            onPressed: () {
              if (layout != null) {
                editorProvider.fitToScreen(context);
              }
            },
          ),
        ],
      ),
    );
  }
}
