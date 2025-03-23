import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add this import for keyboard shortcuts
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/layouts.dart';
import '../providers/layouts.dart';
import '../providers/layout_editor.dart';
import '../components/layout_editor_components/canvas_workspace.dart';
import '../components/layout_editor_components/zoom_controls.dart';
import '../components/layout_editor_components/layers_sidebar.dart';
import '../components/layout_editor_components/properties_panel.dart';
import '../components/layout_editor_components/multi_selection_properties_panel.dart'; // Add this import
import '../components/layout_editor_components/background_properties_panel.dart';
import '../components/layout_editor_components/editor_footer.dart'; // Add this import
// Use a prefix for this import to avoid conflicts

class LayoutEditor extends StatelessWidget {
  final Layouts layout;
  final int layoutIndex;

  const LayoutEditor({
    super.key,
    required this.layout,
    required this.layoutIndex,
  });

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

  const LayoutEditorScreen({super.key, required this.layoutIndex});

  @override
  LayoutEditorScreenState createState() => LayoutEditorScreenState();
}

class LayoutEditorScreenState extends State<LayoutEditorScreen> {
  // Add a flag to track if there are unsaved changes
  bool _hasUnsavedChanges = false;

  // Create a focus node to handle keyboard shortcuts
  final FocusNode _shortcutFocusNode = FocusNode();

  @override
  void dispose() {
    _shortcutFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editorProvider = Provider.of<LayoutEditorProvider>(context);
    final layout = editorProvider.layout;

    // Listen for changes and update the unsaved changes flag
    editorProvider.addListener(() {
      if (!_hasUnsavedChanges) {
        setState(() {
          _hasUnsavedChanges = true;
        });
      }
    });

    if (layout == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Use KeyboardListener with different key detection approach
    return Focus(
      focusNode: _shortcutFocusNode,
      autofocus: true,
      onKeyEvent: (_, KeyEvent event) {
        // Debug the received key event
        print(
          'Key event: ${event.runtimeType} - logical: ${event.logicalKey.keyLabel}, '
          'physical: ${event.physicalKey.usbHidUsage}',
        );

        // Try to handle the shortcut in the provider first
        if (editorProvider.handleKeyboardShortcut(event)) {
          return KeyEventResult.handled;
        }

        // Check for Ctrl+S using both key types for robustness
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyS &&
            (HardwareKeyboard.instance.isControlPressed)) {
          // Support both Ctrl and Command
          _saveLayout(context);
          return KeyEventResult.handled;
        }

        // Check for Ctrl+G to group elements
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyG &&
            HardwareKeyboard.instance.isControlPressed) {
          if (HardwareKeyboard.instance.isShiftPressed) {
            // Ctrl+Shift+G = Ungroup
            editorProvider.ungroupSelectedElements();
          } else {
            // Ctrl+G = Group
            editorProvider.groupSelectedElements();
          }
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      // Replace WillPopScope with PopScope
      child: PopScope<dynamic>(
        canPop: !_hasUnsavedChanges, // Only allow popping if no unsaved changes
        onPopInvokedWithResult: (didPop, dynamic result) async {
          // If didPop is true, the pop was allowed and already happened
          if (didPop) {
            return;
          }

          // If we have unsaved changes, show the dialog
          if (_hasUnsavedChanges) {
            final bool? shouldPop = await _showUnsavedChangesDialog(context);
            // If user confirmed saving/discarding and the context is still valid
            if (context.mounted && shouldPop == true) {
              Navigator.of(context).pop(result);
            }
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text('Editing: ${layout.name}'),
            actions: [
              // Replace the simple IconButton with a TextButton.icon
              TextButton.icon(
                icon: Icon(
                  _hasUnsavedChanges
                      ? Icons
                          .save_outlined // Different icon for unsaved changes
                      : Icons.check_circle_outline, // Icon for saved state
                  color:
                      _hasUnsavedChanges
                          ? Theme.of(context).colorScheme.primary
                          : Colors.green, // Indicate saved with green color
                ),
                label: Text(
                  _hasUnsavedChanges ? 'Save' : 'Saved',
                  style: TextStyle(
                    color:
                        _hasUnsavedChanges
                            ? Theme.of(context).colorScheme.primary
                            : Colors.green,
                  ),
                ),
                onPressed: () => _saveLayout(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ],
          ),
          body: Column(
            // Change from Row to Column to add footer at bottom
            children: [
              // Main content in an Expanded widget
              Expanded(
                child: Row(
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
                            Positioned(
                              right: 16,
                              bottom: 80,
                              child: ZoomControls(),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Right sidebar with properties panel
                    SizedBox(
                      width: 280,
                      child:
                          editorProvider.hasMultipleElementsSelected
                              ? MultiSelectionPropertiesPanel(
                                selectedElements:
                                    editorProvider.selectedElements,
                              )
                              : editorProvider.selectedElement != null
                              ? PropertiesPanel(
                                element: editorProvider.selectedElement!,
                              )
                              : BackgroundPropertiesPanel(),
                    ),
                  ],
                ),
              ),

              // Footer with project information
              const EditorFooter(),
            ],
          ),
          // Remove bottomNavigationBar to prevent conflict with EditorFooter
          // bottomNavigationBar: ToolbarContainer(),
        ),
      ),
    );
  }

  // Add method to show the confirmation dialog
  Future<bool?> _showUnsavedChangesDialog(BuildContext context) async {
    // Capture the editorProvider before showing the dialog
    final editorProvider = Provider.of<LayoutEditorProvider>(
      context,
      listen: false,
    );
    final layoutsProvider = Provider.of<LayoutsProvider>(
      context,
      listen: false,
    );

    return await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Unsaved Changes'),
            content: const Text(
              'You have unsaved changes. Do you want to save them before leaving?',
            ),
            actions: [
              TextButton(
                onPressed:
                    () => Navigator.of(
                      dialogContext,
                    ).pop(false), // Don't save, continue navigation
                child: const Text('Discard'),
              ),
              TextButton(
                onPressed:
                    () => Navigator.of(
                      dialogContext,
                    ).pop(null), // Cancel navigation
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Save the layout using the providers captured from the parent context
                  if (editorProvider.layout != null) {
                    await layoutsProvider.editLayout(
                      widget.layoutIndex,
                      editorProvider.layout!,
                    );

                    // Only update UI if the widget is still mounted
                    if (context.mounted) {
                      // Mark changes as saved
                      setState(() {
                        _hasUnsavedChanges = false;
                      });

                      // Show success message
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Layout saved successfully'),
                        ),
                      );
                    }
                  }

                  // Close the dialog and continue navigation
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(true);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
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
        // Mark changes as saved
        setState(() {
          _hasUnsavedChanges = false;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Layout saved successfully')),
        );

        // Remove Navigator.pop() to stay on the current screen
      }
    }
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
