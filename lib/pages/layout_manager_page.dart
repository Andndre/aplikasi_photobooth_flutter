import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photobooth/components/dialogs/add_layout_dialog.dart';
import 'package:photobooth/components/dialogs/render_layout_manually.dart';
import 'package:photobooth/models/layout_model.dart';
import 'package:photobooth/models/renderables/image_element.dart';
import 'package:photobooth/providers/layout_editor_provider.dart';
import 'package:photobooth/providers/layout_provider.dart';
import 'package:photobooth/screens/layout_editor_screen.dart';
import 'package:provider/provider.dart';

class LayoutManager extends StatefulWidget {
  const LayoutManager({super.key});

  @override
  State<LayoutManager> createState() => _LayoutManagerState();
}

class _LayoutManagerState extends State<LayoutManager> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Layout Manager')),
      body: FutureBuilder(
        future:
            Provider.of<LayoutsProvider>(context, listen: false).loadLayouts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else {
            return Consumer<LayoutsProvider>(
              builder: (context, layoutsProvider, child) {
                if (layoutsProvider.layouts.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.photo_size_select_actual,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No layouts available',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Click the + button to create one',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                } else {
                  return LayoutsList(layoutsProvider: layoutsProvider);
                }
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const AddLayoutDialog(),
          );
        },
        tooltip: 'Create New Layout',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class LayoutsList extends StatelessWidget {
  final LayoutsProvider layoutsProvider;

  const LayoutsList({super.key, required this.layoutsProvider});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: layoutsProvider.layouts.length,
      itemBuilder: (context, index) {
        final layout = layoutsProvider.layouts[index];
        return LayoutCard(layout: layout, index: index);
      },
    );
  }
}

class LayoutCard extends StatelessWidget {
  final LayoutModel layout;
  final int index;

  const LayoutCard({required this.layout, required this.index, super.key});

  @override
  Widget build(BuildContext context) {
    // Find background image (if any) from elements
    String backgroundImagePath = '';
    for (var element in layout.elements) {
      if (element.type == 'image') {
        backgroundImagePath = (element as ImageElement).path;
        break;
      }
    }

    // Count camera spots
    int cameraSpots = layout.elements.where((e) => e.type == 'camera').length;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Layout preview
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                backgroundImagePath.isNotEmpty &&
                        File(backgroundImagePath).existsSync()
                    ? Image.file(File(backgroundImagePath), fit: BoxFit.cover)
                    : Container(
                      color: _hexToColor(layout.backgroundColor),
                      child: const Icon(Icons.image_not_supported, size: 48),
                    ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${layout.width}x${layout.height}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Layout info and actions
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  layout.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${layout.id} • ${cameraSpots > 0 ? "$cameraSpots photo spots" : "No photo spots"}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () {
                        LayoutEditorProvider provider =
                            Provider.of<LayoutEditorProvider>(
                              context,
                              listen: false,
                            );
                        // Set selected layout for layout editor
                        provider.setLayout(layout);
                        // Navigate directly to the layout editor
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (context) =>
                                    LayoutEditorScreen(layoutIndex: index),
                          ),
                        );
                      },
                      tooltip: 'Edit',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('Confirm Delete'),
                              content: const Text(
                                'Are you sure you want to delete this layout?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Provider.of<LayoutsProvider>(
                                      context,
                                      listen: false,
                                    ).removeLayout(index);
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('Delete'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      tooltip: 'Delete',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.image),
                      label: const Text('Render with Photos'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) =>
                                    RenderLayoutManually(layout: layout),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to convert hex color string to Color
  Color _hexToColor(String hexColor) {
    if (hexColor == 'transparent') return Colors.transparent;

    hexColor = hexColor.replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    return Color(int.parse(hexColor, radix: 16));
  }
}
