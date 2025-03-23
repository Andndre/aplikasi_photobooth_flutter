import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/layout_editor.dart';
import '../components/layout_editor_components/layers_sidebar.dart';
import '../components/layout_editor_components/canvas_workspace.dart';
import '../components/layout_editor_components/properties_panel.dart';
import '../components/layout_editor_components/background_properties_panel.dart';
import '../components/layout_editor_components/zoom_controls.dart';
import '../components/layout_editor_components/multi_selection_properties_panel.dart';
import '../components/layout_editor_components/editor_footer.dart';

class LayoutEditorScreen extends StatelessWidget {
  const LayoutEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final editorProvider = Provider.of<LayoutEditorProvider>(context);

    return Scaffold(
      body: Column(
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
                  width: 300, // Fixed width for properties panel
                  child:
                      editorProvider.hasMultipleElementsSelected
                          ? MultiSelectionPropertiesPanel(
                            selectedElements: editorProvider.selectedElements,
                          )
                          : editorProvider.selectedElement != null
                          ? PropertiesPanel(
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
