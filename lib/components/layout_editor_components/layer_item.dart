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
    final editorProvider = Provider.of<LayoutEditorProvider>(context);
    final isSelected = editorProvider.selectedElement?.id == element.id;

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

    return ListTile(
      dense: true,
      selected: isSelected,
      tileColor:
          isSelected
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
              : null,
      leading: Icon(
        elementIcon,
        color:
            element.isVisible
                ? isSelected
                    ? Theme.of(context).colorScheme.primary
                    : null
                : Colors.grey,
      ),
      title: Text(
        elementName,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          decoration: !element.isVisible ? TextDecoration.lineThrough : null,
          color: !element.isVisible ? Colors.grey : null,
        ),
      ),
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
          IconButton(
            icon: const Icon(Icons.more_vert, size: 18),
            tooltip: 'More options',
            onPressed: () => _showLayerOptions(context, editorProvider),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          ),
        ],
      ),
      onTap: () {
        editorProvider.selectElement(element);
      },
    );
  }

  void _showLayerOptions(
    BuildContext context,
    LayoutEditorProvider editorProvider,
  ) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.of(context).pop();
                  editorProvider.deleteElement(element.id);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Duplicate'),
                onTap: () {
                  Navigator.of(context).pop();
                  editorProvider.copyElement(element.id);
                  editorProvider.pasteElement();
                },
              ),
              ListTile(
                leading: const Icon(Icons.vertical_align_top),
                title: const Text('Bring to Front'),
                onTap: () {
                  Navigator.of(context).pop();
                  editorProvider.bringToFront(element.id);
                },
              ),
              ListTile(
                leading: const Icon(Icons.vertical_align_bottom),
                title: const Text('Send to Back'),
                onTap: () {
                  Navigator.of(context).pop();
                  editorProvider.sendToBack(element.id);
                },
              ),
              // Add element-specific options
              if (element.type == 'text')
                ListTile(
                  leading: const Icon(Icons.text_fields),
                  title: const Text('Edit Text'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _editTextElement(
                      context,
                      editorProvider,
                      element as TextElement,
                    );
                  },
                ),
              if (element.type == 'image')
                ListTile(
                  leading: const Icon(Icons.image),
                  title: const Text('Replace Image'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _replaceImage(
                      context,
                      editorProvider,
                      element as ImageElement,
                    );
                  },
                ),
            ],
          ),
    );
  }

  // Future<List<String>> _loadSystemFonts() async {
  //   // Default fonts as fallback
  //   List<String> fonts = [
  //     'Arial',
  //     'Helvetica',
  //     'Times New Roman',
  //     'Courier',
  //     'Verdana',
  //   ];

  //   try {
  //     // Try to load system fonts
  //     final systemFonts = await SystemFonts.getAvailableFonts();
  //     fonts = [...fonts, ...systemFonts];

  //     // Remove duplicates and sort
  //     fonts = fonts.toSet().toList()..sort();
  //   } catch (e) {
  //     print('Error loading system fonts: $e');
  //   }

  //   return fonts;
  // }

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
