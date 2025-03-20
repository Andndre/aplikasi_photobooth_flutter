import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/layouts.dart';
import '../providers/layouts.dart';
import '../providers/layout_editor.dart';
import '../components/layout_editor_components/canvas_workspace.dart';
import '../components/layout_editor_components/zoom_controls.dart';
import '../components/layout_editor_components/layers_sidebar.dart';
import '../components/layout_editor_components/properties_panel.dart';
import '../components/layout_editor_components/background_properties_panel.dart';
import '../components/layout_editor_components/element_widget.dart';
// Use a prefix for this import to avoid conflicts
import '../components/layout_editor_components/selection_overlay.dart'
    as custom_overlay;

class LayoutEditor extends StatelessWidget {
  final Layouts layout;
  final int layoutIndex;

  const LayoutEditor({
    Key? key,
    required this.layout,
    required this.layoutIndex,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final provider = LayoutEditorProvider();
        provider.setLayout(layout);
        return provider;
      },
      child: LayoutEditorScreen(layoutIndex: layoutIndex),
    );
  }
}

class LayoutEditorScreen extends StatefulWidget {
  final int layoutIndex;

  const LayoutEditorScreen({Key? key, required this.layoutIndex})
    : super(key: key);

  @override
  LayoutEditorScreenState createState() => LayoutEditorScreenState();
}

class LayoutEditorScreenState extends State<LayoutEditorScreen> {
  @override
  Widget build(BuildContext context) {
    final editorProvider = Provider.of<LayoutEditorProvider>(context);
    final layout = editorProvider.layout;

    if (layout == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Editing: ${layout.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save layout',
            onPressed: () => _saveLayout(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Editor settings',
            onPressed: () => _showEditorSettings(context),
          ),
        ],
      ),
      body: Row(
        children: [
          // Left sidebar with layers
          SizedBox(width: 250, child: LayersSidebar()),

          // Main canvas area
          Expanded(
            flex: 3,
            child: Center(
              child: Stack(
                children: [
                  // Canvas workspace
                  Positioned.fill(child: CanvasWorkspace()),

                  // Zoom controls
                  Positioned(right: 16, bottom: 80, child: ZoomControls()),
                ],
              ),
            ),
          ),

          // Right sidebar with properties panel
          SizedBox(
            width: 280,
            child:
                editorProvider.selectedElement != null
                    ? PropertiesPanel(element: editorProvider.selectedElement!)
                    : BackgroundPropertiesPanel(),
          ),
        ],
      ),
      bottomNavigationBar: ToolbarContainer(),
    );
  }

  Future<void> _saveLayout(BuildContext context) async {
    final editorProvider = Provider.of<LayoutEditorProvider>(
      context,
      listen: false,
    );
    final layoutsProvider = Provider.of<LayoutsProvider>(
      context,
      listen: false,
    );

    if (editorProvider.layout != null) {
      await layoutsProvider.editLayout(
        widget.layoutIndex,
        editorProvider.layout!,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Layout saved successfully')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  void _showEditorSettings(BuildContext context) {
    final editorProvider = Provider.of<LayoutEditorProvider>(
      context,
      listen: false,
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Editor Settings'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Show Grid'),
                  value: editorProvider.showGrid,
                  onChanged: (value) {
                    editorProvider.toggleGrid();
                    Navigator.of(context).pop();
                  },
                ),
                SwitchListTile(
                  title: const Text('Snap to Grid'),
                  value: editorProvider.snapToGrid,
                  onChanged: (value) {
                    editorProvider.toggleSnapToGrid();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }
}

class ToolbarContainer extends StatelessWidget {
  const ToolbarContainer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final editorProvider = Provider.of<LayoutEditorProvider>(context);

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildToolbarButton(
            context,
            icon: Icons.pan_tool,
            label: 'Select',
            isSelected: editorProvider.editMode == EditMode.select,
            onPressed: () => editorProvider.setEditMode(EditMode.select),
          ),
          _buildToolbarButton(
            context,
            icon: Icons.text_fields,
            label: 'Text',
            isSelected: editorProvider.editMode == EditMode.text,
            onPressed: () {
              editorProvider.setEditMode(EditMode.text);
              editorProvider.addTextElement();
            },
          ),
          _buildToolbarButton(
            context,
            icon: Icons.image,
            label: 'Image',
            isSelected: editorProvider.editMode == EditMode.image,
            onPressed: () async {
              editorProvider.setEditMode(EditMode.image);
              final result = await FilePicker.platform.pickFiles(
                type: FileType.image,
                allowMultiple: false,
              );

              if (result != null &&
                  result.files.isNotEmpty &&
                  result.files.first.path != null) {
                editorProvider.addImageElement(result.files.first.path!);
              }
            },
          ),
          _buildToolbarButton(
            context,
            icon: Icons.camera_alt,
            label: 'Camera',
            isSelected: editorProvider.editMode == EditMode.camera,
            onPressed: () {
              editorProvider.setEditMode(EditMode.camera);
              editorProvider.addCameraElement();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(icon),
            onPressed: onPressed,
            color: isSelected ? Theme.of(context).colorScheme.primary : null,
            tooltip: label,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color:
                  isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.7),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
