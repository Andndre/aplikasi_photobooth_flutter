import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/layouts.dart';
import '../../providers/layout_editor.dart';

class LayerItem extends StatelessWidget {
  final LayoutElement element;

  const LayerItem({Key? key, required this.element}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Fix: Use listen: false to avoid rebuilds during drag operations
    final editorProvider = Provider.of<LayoutEditorProvider>(
      context,
      listen: false,
    );
    // Only listen to selectedElement changes for highlighting
    final selectedElementId =
        Provider.of<LayoutEditorProvider>(context).selectedElement?.id;
    final isSelected = selectedElementId == element.id;

    String elementName;
    IconData elementIcon;

    switch (element.type) {
      case 'image':
        final imageElement = element as ImageElement;
        elementName = 'Image: ${imageElement.path.split('/').last}';
        elementIcon = Icons.image;
        break;
      case 'text':
        final textElement = element as TextElement;
        elementName =
            'Text: ${textElement.text.length > 15 ? '${textElement.text.substring(0, 15)}...' : textElement.text}';
        elementIcon = Icons.text_fields;
        break;
      case 'camera':
        final cameraElement = element as CameraElement;
        elementName = cameraElement.label;
        elementIcon = Icons.camera_alt;
        break;
      default:
        elementName = 'Unknown element';
        elementIcon = Icons.help;
    }

    // Wrap the ListTile with a GestureDetector for right-click context menu
    return GestureDetector(
      onSecondaryTap: () {
        // Show context menu on right-click
        _showContextMenu(context, editorProvider);
      },
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        selected: isSelected,
        selectedTileColor: Colors.transparent,
        // Add a drag handle at the start
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!element.isLocked)
              Icon(
                Icons.drag_handle,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            const SizedBox(width: 4),
            Icon(
              elementIcon,
              color:
                  element.isVisible
                      ? (isSelected
                          ? Theme.of(context).colorScheme.primary
                          : null)
                      : Colors.grey,
            ),
          ],
        ),
        title: Text(
          elementName,
          style: TextStyle(
            fontWeight: FontWeight.normal,
            color:
                isSelected
                    ? Theme.of(context).colorScheme.primary
                    : (!element.isVisible ? Colors.grey : null),
            decoration: !element.isVisible ? TextDecoration.lineThrough : null,
          ),
        ),
        // Keep only visibility and lock toggles, remove the more options button
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                element.isVisible ? Icons.visibility : Icons.visibility_off,
                size: 18,
              ),
              tooltip: element.isVisible ? 'Hide' : 'Show',
              onPressed: () {
                editorProvider.toggleElementVisibility(element.id);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            ),
            IconButton(
              icon: Icon(
                element.isLocked ? Icons.lock : Icons.lock_open,
                size: 18,
              ),
              tooltip: element.isLocked ? 'Unlock' : 'Lock',
              onPressed: () {
                editorProvider.toggleElementLock(element.id);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            ),
            // More options button removed in favor of right-click menu
          ],
        ),
        onTap: () {
          editorProvider.selectElement(element);
        },
        onLongPress: () {
          // Show context menu on long press for mobile support
          _showContextMenu(context, editorProvider);
        },
      ),
    );
  }

  // Method to show context menu - can be called from right-click or long press
  void _showContextMenu(
    BuildContext context,
    LayoutEditorProvider editorProvider,
  ) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + size.height,
        position.dx + size.width,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'duplicate',
          child: Row(
            children: [
              Icon(Icons.copy, size: 18),
              const SizedBox(width: 8),
              const Text('Duplicate'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'bringToFront',
          child: Row(
            children: [
              Icon(Icons.vertical_align_top, size: 18),
              const SizedBox(width: 8),
              const Text('Bring to Front'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'sendToBack',
          child: Row(
            children: [
              Icon(Icons.vertical_align_bottom, size: 18),
              const SizedBox(width: 8),
              const Text('Send to Back'),
            ],
          ),
        ),
        if (element.type == 'text')
          PopupMenuItem(
            value: 'editText',
            child: Row(
              children: [
                Icon(Icons.text_fields, size: 18),
                const SizedBox(width: 8),
                const Text('Edit Text'),
              ],
            ),
          ),
        if (element.type == 'image')
          PopupMenuItem(
            value: 'replaceImage',
            child: Row(
              children: [
                Icon(Icons.image, size: 18),
                const SizedBox(width: 8),
                const Text('Replace Image'),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete,
                size: 18,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 8),
              const Text('Delete'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;

      switch (value) {
        case 'delete':
          editorProvider.deleteElement(element.id);
          break;
        case 'duplicate':
          editorProvider.copyElement(element.id);
          editorProvider.pasteElement();
          break;
        case 'bringToFront':
          editorProvider.bringToFront(element.id);
          break;
        case 'sendToBack':
          editorProvider.sendToBack(element.id);
          break;
        case 'editText':
          _editTextElement(context, editorProvider, element as TextElement);
          break;
        case 'replaceImage':
          _replaceImage(context, editorProvider, element as ImageElement);
          break;
      }
    });
  }

  // Existing _showLayerOptions method can be removed

  void _editTextElement(
    BuildContext context,
    LayoutEditorProvider editorProvider,
    TextElement element,
  ) {
    final TextEditingController textController = TextEditingController(
      text: element.text,
    );
    final TextEditingController fontSearchController = TextEditingController();

    // Set text selection to end to ensure cursor is at the end when editing
    textController.selection = TextSelection.fromPosition(
      TextPosition(offset: textController.text.length),
    );

    String selectedFontFamily = element.fontFamily;
    double fontSize = element.fontSize;
    bool isBold = element.isBold;
    bool isItalic = element.isItalic;
    String alignment = element.alignment;
    Color textColor = _hexToColor(element.color);
    Color backgroundColor = _hexToColor(element.backgroundColor);

    // List of common fonts
    final List<String> commonFonts = [
      'Arial',
      'Helvetica',
      'Roboto',
      'Times New Roman',
      'Courier New',
      'Verdana',
      'Georgia',
      'Tahoma',
      'Trebuchet MS',
      'Impact',
      'Comic Sans MS',
      'Arial Black',
      'Palatino',
      'Garamond',
      'Calibri',
      'Cambria',
      'Segoe UI',
      'Open Sans',
      'Lato',
      'Montserrat',
    ];

    // For font list
    List<String> allFonts = commonFonts;
    List<String> filteredFonts = allFonts;
    bool isLoadingFonts = true;

    // Add this function to create a dropdown for font selection
    Widget buildFontFamilyDropdown(
      String currentFont,
      Function(String) onFontChanged,
      List<String> fonts,
    ) {
      return DropdownButtonFormField<String>(
        value: currentFont,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Font Family',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        items:
            fonts.map((font) {
              return DropdownMenuItem<String>(
                value: font,
                child: Text(
                  font,
                  style: TextStyle(fontFamily: font),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
        onChanged: (value) {
          if (value != null) {
            onFontChanged(value);
          }
        },
      );
    }

    // showDialog(
    //   context: context,
    //   builder:
    //       (context) => StatefulBuilder(
    //         builder: (context, setState) {
    //           // Load system fonts when dialog opens
    //           if (isLoadingFonts) {
    //             _loadSystemFonts().then((fonts) {
    //               setState(() {
    //                 allFonts = fonts;
    //                 filteredFonts = fonts;
    //                 isLoadingFonts = false;
    //               });
    //             });
    //           }

    //           void filterFonts(String query) {
    //             setState(() {
    //               if (query.isEmpty) {
    //                 filteredFonts = allFonts;
    //               } else {
    //                 filteredFonts =
    //                     allFonts
    //                         .where(
    //                           (font) => font.toLowerCase().contains(
    //                             query.toLowerCase(),
    //                           ),
    //                         )
    //                         .toList();
    //               }
    //             });
    //           }

    //           return AlertDialog(
    //             title: const Text('Edit Text'),
    //             content: SingleChildScrollView(
    //               child: Column(
    //                 mainAxisSize: MainAxisSize.min,
    //                 crossAxisAlignment: CrossAxisAlignment.start,
    //                 children: [
    //                   // Text input field with proper direction
    //                   TextField(
    //                     controller: textController,
    //                     decoration: const InputDecoration(
    //                       labelText: 'Text',
    //                       border: OutlineInputBorder(),
    //                     ),
    //                     textDirection: TextDirection.ltr,
    //                     maxLines: 3,
    //                   ),

    //                   const SizedBox(height: 16),

    //                   // Font family with search
    //                   const Text('Font Family'),
    //                   const SizedBox(height: 4),
    //                   buildFontFamilyDropdown(
    //                     selectedFontFamily,
    //                     (font) => setState(() => selectedFontFamily = font),
    //                     commonFonts,
    //                   ),

    //                   const SizedBox(height: 8),

    //                   // Font list
    //                   Container(
    //                     height: 150,
    //                     decoration: BoxDecoration(
    //                       border: Border.all(color: Colors.grey.shade300),
    //                       borderRadius: BorderRadius.circular(4),
    //                     ),
    //                     child: ListView.builder(
    //                       itemCount: filteredFonts.length,
    //                       itemBuilder: (context, index) {
    //                         final font = filteredFonts[index];
    //                         final isSelected = font == selectedFontFamily;

    //                         return ListTile(
    //                           title: Text(
    //                             font,
    //                             style: TextStyle(
    //                               fontFamily: font,
    //                               fontWeight:
    //                                   isSelected
    //                                       ? FontWeight.bold
    //                                       : FontWeight.normal,
    //                             ),
    //                           ),
    //                           dense: true,
    //                           selected: isSelected,
    //                           onTap: () {
    //                             setState(() {
    //                               selectedFontFamily = font;
    //                             });
    //                           },
    //                           trailing:
    //                               isSelected
    //                                   ? const Icon(Icons.check, size: 16)
    //                                   : null,
    //                         );
    //                       },
    //                     ),
    //                   ),

    //                   const SizedBox(height: 16),

    //                   // Font size slider
    //                   Row(
    //                     children: [
    //                       const Text('Size:'),
    //                       Expanded(
    //                         child: Slider(
    //                           value: fontSize,
    //                           min: 8,
    //                           max: 72,
    //                           divisions: 64,
    //                           onChanged: (value) {
    //                             setState(() {
    //                               fontSize = value;
    //                             });
    //                           },
    //                         ),
    //                       ),
    //                       Text('${fontSize.round()} px'),
    //                     ],
    //                   ),

    //                   // Style options (bold, italic)
    //                   Row(
    //                     children: [
    //                       const Text('Style:'),
    //                       const SizedBox(width: 16),
    //                       ChoiceChip(
    //                         label: const Text('Bold'),
    //                         selected: isBold,
    //                         onSelected: (selected) {
    //                           setState(() {
    //                             isBold = selected;
    //                           });
    //                         },
    //                       ),
    //                       const SizedBox(width: 8),
    //                       ChoiceChip(
    //                         label: const Text('Italic'),
    //                         selected: isItalic,
    //                         onSelected: (selected) {
    //                           setState(() {
    //                             isItalic = selected;
    //                           });
    //                         },
    //                       ),
    //                     ],
    //                   ),

    //                   const SizedBox(height: 16),

    //                   // Alignment options
    //                   const Text('Alignment:'),
    //                   Row(
    //                     children: [
    //                       Expanded(
    //                         child: RadioListTile<String>(
    //                           title: const Icon(Icons.format_align_left),
    //                           value: 'left',
    //                           groupValue: alignment,
    //                           onChanged: (value) {
    //                             setState(() {
    //                               alignment = value!;
    //                             });
    //                           },
    //                         ),
    //                       ),
    //                       Expanded(
    //                         child: RadioListTile<String>(
    //                           title: const Icon(Icons.format_align_center),
    //                           value: 'center',
    //                           groupValue: alignment,
    //                           onChanged: (value) {
    //                             setState(() {
    //                               alignment = value!;
    //                             });
    //                           },
    //                         ),
    //                       ),
    //                       Expanded(
    //                         child: RadioListTile<String>(
    //                           title: const Icon(Icons.format_align_right),
    //                           value: 'right',
    //                           groupValue: alignment,
    //                           onChanged: (value) {
    //                             setState(() {
    //                               alignment = value!;
    //                             });
    //                           },
    //                         ),
    //                       ),
    //                     ],
    //                   ),

    //                   const SizedBox(height: 16),

    //                   // Color options
    //                   Row(
    //                     children: [
    //                       Expanded(
    //                         child: ElevatedButton(
    //                           onPressed: () async {
    //                             // Show color picker for text
    //                             // ...existing color picker code...
    //                           },
    //                           child: Row(
    //                             mainAxisAlignment: MainAxisAlignment.center,
    //                             children: [
    //                               Container(
    //                                 width: 16,
    //                                 height: 16,
    //                                 decoration: BoxDecoration(
    //                                   color: textColor,
    //                                   border: Border.all(color: Colors.grey),
    //                                 ),
    //                               ),
    //                               const SizedBox(width: 8),
    //                               const Text('Text Color'),
    //                             ],
    //                           ),
    //                         ),
    //                       ),
    //                       const SizedBox(width: 8),
    //                       Expanded(
    //                         child: ElevatedButton(
    //                           onPressed: () async {
    //                             // Show color picker for background
    //                             // ...existing color picker code...
    //                           },
    //                           child: Row(
    //                             mainAxisAlignment: MainAxisAlignment.center,
    //                             children: [
    //                               Container(
    //                                 width: 16,
    //                                 height: 16,
    //                                 decoration: BoxDecoration(
    //                                   color: backgroundColor,
    //                                   border: Border.all(color: Colors.grey),
    //                                 ),
    //                               ),
    //                               const SizedBox(width: 8),
    //                               const Text('Background'),
    //                             ],
    //                           ),
    //                         ),
    //                       ),
    //                     ],
    //                   ),
    //                 ],
    //               ),
    //             ),
    //             actions: [
    //               TextButton(
    //                 onPressed: () => Navigator.of(context).pop(),
    //                 child: const Text('Cancel'),
    //               ),
    //               TextButton(
    //                 onPressed: () {
    //                   // Update the text element
    //                   editorProvider.updateTextElement(
    //                     element.id,
    //                     text: textController.text,
    //                     fontFamily: selectedFontFamily,
    //                     fontSize: fontSize,
    //                     color:
    //                         '#${textColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
    //                     backgroundColor:
    //                         '#${backgroundColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
    //                     isBold: isBold,
    //                     isItalic: isItalic,
    //                     alignment: alignment,
    //                   );
    //                   Navigator.of(context).pop();
    //                 },
    //                 child: const Text('Apply'),
    //               ),
    //             ],
    //           );
    //         },
    //       ),
    // );
  }

  void _replaceImage(
    BuildContext context,
    LayoutEditorProvider editorProvider,
    ImageElement element,
  ) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null && result.files.single.path != null) {
      editorProvider.updateImageElement(
        element.id,
        path: result.files.single.path!,
      );
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
