import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/layout_editor.dart';

class ZoomControls extends StatelessWidget {
  const ZoomControls({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final editorProvider = Provider.of<LayoutEditorProvider>(context);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
              '${(editorProvider.scale * 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove),
            tooltip: 'Zoom out',
            onPressed: () {
              editorProvider.zoom(1 / 1.2);
            },
          ),
          const Divider(height: 1),
          IconButton(
            icon: const Icon(Icons.fit_screen),
            tooltip: 'Fit to screen',
            onPressed: () {
              editorProvider.resetZoom();
            },
          ),
        ],
      ),
    );
  }
}
