import 'package:flutter/material.dart';
import 'package:photobooth/components/layout_editor/canvas_workspace.dart';
import 'package:photobooth/components/layout_editor/editor_footer.dart';
import 'package:photobooth/components/layout_editor/layers_sidebar.dart';
import 'package:photobooth/components/layout_editor/properties_panel/background.dart';
import 'package:photobooth/components/layout_editor/properties_panel/multiple_elements.dart';
import 'package:photobooth/components/layout_editor/properties_panel/single_element.dart';
import 'package:photobooth/components/layout_editor/zoom_controls.dart';
import 'package:photobooth/models/layout_model.dart';
import 'package:photobooth/providers/layout_editor_provider.dart';
import 'package:provider/provider.dart';

class LayoutEditorScreen extends StatefulWidget {
  const LayoutEditorScreen({super.key, required this.layoutIndex});
  final int layoutIndex;

  @override
  State<LayoutEditorScreen> createState() => _LayoutEditorScreenState();
}

class _LayoutEditorScreenState extends State<LayoutEditorScreen> {
  final FocusNode _shortcutFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _shortcutFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editorProvider = Provider.of<LayoutEditorProvider>(context);
    LayoutModel? layout = editorProvider.layout;

    if (layout == null) {
      // TODO
      return Placeholder();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Editing: ${editorProvider.layout!.name}'),
        actions: [
          TextButton.icon(
            icon: Icon(
              editorProvider.hasUnsavedChanges
                  ? Icons
                      .save_outlined // Different icon for unsaved changes
                  : Icons.check_circle_outline, // Icon for saved state
              color:
                  editorProvider.hasUnsavedChanges
                      ? Theme.of(context).colorScheme.primary
                      : Colors.green, // Indicate saved with green color
            ),
            label: Text(
              editorProvider.hasUnsavedChanges ? 'Save' : 'Saved',
              style: TextStyle(
                color:
                    editorProvider.hasUnsavedChanges
                        ? Theme.of(context).colorScheme.primary
                        : Colors.green,
              ),
            ),
            onPressed:
                () => editorProvider.saveLayout(context, widget.layoutIndex),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ],
      ),
      body:
          editorProvider.isLoadingFonts
              ? Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Main content in an Expanded widget
                  Expanded(
                    child: Row(
                      children: [
                        // Layers sidebar
                        const SizedBox(
                          width: 240, // Fixed width for sidebar
                          child: LayersSidebar(),
                        ),

                        // Main workspace
                        Expanded(
                          child: Stack(
                            children: [
                              const CanvasWorkspace(),
                              // Zoom controls
                              const Positioned(
                                right: 16,
                                bottom: 16,
                                child: ZoomControls(),
                              ),
                            ],
                          ),
                        ),

                        // Properties panel - choose appropriate panel based on selection
                        SizedBox(
                          width: 300,
                          child:
                              editorProvider.hasMultipleElementsSelected
                                  ? MultipleElementsPropertiesPanel(
                                    selectedElements:
                                        editorProvider.selectedElements,
                                  )
                                  : editorProvider.selectedElement != null
                                  ? SingleElementPropertiesPanel(
                                    element: editorProvider.selectedElement!,
                                  )
                                  : const BackgroundPropertiesPanel(),
                        ),
                      ],
                    ),
                  ),

                  // Footer with project information
                  const EditorFooter(),
                ],
              ),
    );
  }
}
