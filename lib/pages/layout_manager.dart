import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/layouts.dart';
import '../models/layouts.dart';
import 'dart:io';

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
            builder: (context) => const CreateLayoutDialog(),
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

  const LayoutsList({Key? key, required this.layoutsProvider})
    : super(key: key);

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
  final Layouts layout;
  final int index;

  const LayoutCard({required this.layout, required this.index, Key? key})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
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
                layout.basePhoto.isNotEmpty &&
                        File(layout.basePhoto).existsSync()
                    ? Image.file(File(layout.basePhoto), fit: BoxFit.cover)
                    : Container(
                      color: Colors.grey.shade300,
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
                      color: Colors.black.withOpacity(0.7),
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
                  'ID: ${layout.id} • ${layout.coordinates.length} spots',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return EditLayoutDialog(
                              layout: layout,
                              index: index,
                            );
                          },
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
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CreateLayoutDialog extends StatefulWidget {
  const CreateLayoutDialog({Key? key}) : super(key: key);

  @override
  State<CreateLayoutDialog> createState() => _CreateLayoutDialogState();
}

class _CreateLayoutDialogState extends State<CreateLayoutDialog> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  int _width = 1200; // Default to 4R size
  int _height = 1800;
  bool _useCustomResolution = false;

  // Predefined templates - Standard photo paper sizes at 300 DPI
  final List<Map<String, dynamic>> _templates = [
    {
      'name': '4R',
      'description': '4 × 6 inches',
      'width': 1200, // 4 inches × 300 DPI
      'height': 1800, // 6 inches × 300 DPI
      'icon': Icons.photo_size_select_actual,
    },
    {
      'name': '5R',
      'description': '5 × 7 inches',
      'width': 1500, // 5 inches × 300 DPI
      'height': 2100, // 7 inches × 300 DPI
      'icon': Icons.photo_size_select_actual,
    },
    {
      'name': '6R',
      'description': '6 × 8 inches',
      'width': 1800, // 6 inches × 300 DPI
      'height': 2400, // 8 inches × 300 DPI
      'icon': Icons.photo_size_select_actual,
    },
    {
      'name': '8R',
      'description': '8 × 10 inches',
      'width': 2400, // 8 inches × 300 DPI
      'height': 3000, // 10 inches × 300 DPI
      'icon': Icons.photo_size_select_actual,
    },
    {
      'name': 'S8R',
      'description': '8 × 12 inches',
      'width': 2400, // 8 inches × 300 DPI
      'height': 3600, // 12 inches × 300 DPI
      'icon': Icons.photo_size_select_actual,
    },
    {
      'name': '10R',
      'description': '10 × 12 inches',
      'width': 3000, // 10 inches × 300 DPI
      'height': 3600, // 12 inches × 300 DPI
      'icon': Icons.photo_size_select_actual,
    },
    {
      'name': '12R',
      'description': '12 × 16 inches',
      'width': 3600, // 12 inches × 300 DPI
      'height': 4800, // 16 inches × 300 DPI
      'icon': Icons.photo_size_select_large,
    },
    {
      'name': 'A4',
      'description': '8.3 × 11.7 inches',
      'width': 2480, // 8.3 inches × 300 DPI (rounded)
      'height': 3508, // 11.7 inches × 300 DPI (rounded)
      'icon': Icons.description,
    },
    {
      'name': 'Square',
      'description': '8 × 8 inches',
      'width': 2400, // 8 inches × 300 DPI
      'height': 2400, // 8 inches × 300 DPI
      'icon': Icons.crop_square,
    },
    {
      'name': 'Portrait',
      'description': '8 × 10 inches',
      'width': 2400, // 8 inches × 300 DPI
      'height': 3000, // 10 inches × 300 DPI
      'icon': Icons.crop_portrait,
    },
    {
      'name': 'Landscape',
      'description': '10 × 8 inches',
      'width': 3000, // 10 inches × 300 DPI
      'height': 2400, // 8 inches × 300 DPI
      'icon': Icons.crop_landscape,
    },
  ];

  // Controller for width and height text fields
  final TextEditingController _widthController = TextEditingController(
    text: '1200', // Default to 4R width
  );
  final TextEditingController _heightController = TextEditingController(
    text: '1800', // Default to 4R height
  );

  @override
  void initState() {
    super.initState();
    _widthController.addListener(_updateFromControllers);
    _heightController.addListener(_updateFromControllers);
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _updateFromControllers() {
    if (_useCustomResolution) {
      setState(() {
        _width = int.tryParse(_widthController.text) ?? _width;
        _height = int.tryParse(_heightController.text) ?? _height;
      });
    }
  }

  void _selectTemplate(Map<String, dynamic> template) {
    if (!_useCustomResolution) {
      setState(() {
        _width = template['width'];
        _height = template['height'];
        _widthController.text = _width.toString();
        _heightController.text = _height.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dialog header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Create New Layout',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Main content area
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left side - Template selection
                    Expanded(flex: 3, child: _buildTemplateSelector()),

                    const SizedBox(width: 24),

                    // Right side - Layout details form
                    Expanded(flex: 2, child: _buildLayoutDetailsForm()),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Dialog buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _formKey.currentState!.save();

                        // Create a new layout with the specified dimensions
                        final newLayout = Layouts(
                          name: _name,
                          basePhoto: '', // Will be set later in the editor
                          id: 0, // ID will be set by the provider
                          coordinates:
                              [], // Coordinates will be added later in the editor
                          width: _width,
                          height: _height,
                        );

                        Provider.of<LayoutsProvider>(
                          context,
                          listen: false,
                        ).addLayout(newLayout);

                        Navigator.of(context).pop();
                      }
                    },
                    child: const Text('Create Layout'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose a Template',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Standard photo paper sizes at 300 DPI',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Opacity(
            opacity: _useCustomResolution ? 0.5 : 1.0,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.8,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _templates.length,
              itemBuilder: (context, index) {
                final template = _templates[index];
                final bool isSelected =
                    !_useCustomResolution &&
                    _width == template['width'] &&
                    _height == template['height'];

                return InkWell(
                  onTap:
                      _useCustomResolution
                          ? null
                          : () => _selectTemplate(template),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          template['icon'] as IconData,
                          size: 48,
                          color:
                              isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          template['name'] as String,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : null,
                            fontSize: 18,
                            color:
                                isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          template['description'] as String,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${template['width']} × ${template['height']} px',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLayoutDetailsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Layout Details', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 24),

        // Layout name
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Layout Name',
            border: OutlineInputBorder(),
            filled: true,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a layout name';
            }
            return null;
          },
          onSaved: (value) {
            _name = value!;
          },
        ),
        const SizedBox(height: 24),

        // Custom resolution checkbox
        Row(
          children: [
            Checkbox(
              value: _useCustomResolution,
              onChanged: (value) {
                setState(() {
                  _useCustomResolution = value ?? false;
                });
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _useCustomResolution = !_useCustomResolution;
                  });
                },
                child: const Text('Use custom resolution'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Custom resolution fields
        if (_useCustomResolution) ...[
          const Text('Custom Resolution'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _widthController,
                  decoration: const InputDecoration(
                    labelText: 'Width',
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (_useCustomResolution) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final number = int.tryParse(value);
                      if (number == null || number <= 0) {
                        return 'Invalid';
                      }
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _heightController,
                  decoration: const InputDecoration(
                    labelText: 'Height',
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (_useCustomResolution) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final number = int.tryParse(value);
                      if (number == null || number <= 0) {
                        return 'Invalid';
                      }
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ] else ...[
          // Display selected template dimensions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Selected Resolution'),
                const SizedBox(height: 4),
                Text(
                  '$_width × $_height pixels (300 DPI)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(_width / 300).toStringAsFixed(1)} × ${(_height / 300).toStringAsFixed(1)} inches',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  '${(_width / 118.11).toStringAsFixed(1)} × ${(_height / 118.11).toStringAsFixed(1)} cm',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),
        Text(
          'Base image and photo spots can be configured after creating the layout.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}

class EditLayoutDialog extends StatefulWidget {
  final Layouts layout;
  final int index;

  const EditLayoutDialog({required this.layout, required this.index});

  @override
  _EditLayoutDialogState createState() => _EditLayoutDialogState();
}

class _EditLayoutDialogState extends State<EditLayoutDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String _basePhoto;
  late String _coordinatesText;
  late int _width;
  late int _height;
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _name = widget.layout.name;
    _basePhoto = widget.layout.basePhoto;
    _coordinatesText = widget.layout.coordinates
        .map((coord) => coord.join(', '))
        .join('\n');
    _width = widget.layout.width;
    _height = widget.layout.height;
    _widthController.text = _width.toString();
    _heightController.text = _height.toString();

    _widthController.addListener(_updateFromControllers);
    _heightController.addListener(_updateFromControllers);
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _updateFromControllers() {
    setState(() {
      _width = int.tryParse(_widthController.text) ?? _width;
      _height = int.tryParse(_heightController.text) ?? _height;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.6,
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dialog header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Edit Layout',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Form fields in scrollable area
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        initialValue: _name,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                          filled: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a layout name';
                          }
                          return null;
                        },
                        onSaved: (value) {
                          _name = value!;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Resolution
                      Text(
                        'Resolution',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _widthController,
                              decoration: const InputDecoration(
                                labelText: 'Width',
                                border: OutlineInputBorder(),
                                filled: true,
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                final number = int.tryParse(value);
                                if (number == null || number <= 0) {
                                  return 'Invalid';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _heightController,
                              decoration: const InputDecoration(
                                labelText: 'Height',
                                border: OutlineInputBorder(),
                                filled: true,
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                final number = int.tryParse(value);
                                if (number == null || number <= 0) {
                                  return 'Invalid';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Base photo selection
                      ElevatedButton.icon(
                        onPressed: () async {
                          FilePickerResult? result = await FilePicker.platform
                              .pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['png', 'jpg', 'jpeg'],
                              );
                          if (result != null &&
                              result.files.single.path != null) {
                            setState(() {
                              _basePhoto = result.files.single.path!;
                            });
                          }
                        },
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Select Base Photo'),
                      ),

                      if (_basePhoto.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child:
                                    File(_basePhoto).existsSync()
                                        ? Image.file(
                                          File(_basePhoto),
                                          fit: BoxFit.contain,
                                        )
                                        : const Center(
                                          child: Text('Image not found'),
                                        ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton(
                                  icon: const Icon(Icons.close),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.black54,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _basePhoto = '';
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Coordinates
                      Text(
                        'Coordinates',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: _coordinatesText,
                        decoration: const InputDecoration(
                          labelText:
                              'Format: x, y, width, height (one per line)',
                          hintText: '100, 100, 400, 300\n600, 100, 400, 300',
                          border: OutlineInputBorder(),
                          filled: true,
                          alignLabelWithHint: true,
                        ),
                        maxLines: 5,
                        onSaved: (value) {
                          _coordinatesText = value!;
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Note: In the future, we will provide a visual editor to place and resize photo spots.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Dialog buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _formKey.currentState!.save();

                        // Parse coordinates from text
                        final coordinates =
                            _coordinatesText.isEmpty
                                ? <List<int>>[]
                                : _coordinatesText.split('\n').map((line) {
                                  final parts =
                                      line
                                          .split(',')
                                          .map(
                                            (part) =>
                                                int.tryParse(part.trim()) ?? 0,
                                          )
                                          .toList();

                                  // Ensure each coordinate has 4 values (x, y, width, height)
                                  while (parts.length < 4) {
                                    parts.add(0);
                                  }

                                  return parts;
                                }).toList();

                        final updatedLayout = Layouts(
                          name: _name,
                          basePhoto: _basePhoto,
                          id: widget.layout.id,
                          coordinates: coordinates,
                          width: _width,
                          height: _height,
                        );

                        Provider.of<LayoutsProvider>(
                          context,
                          listen: false,
                        ).editLayout(widget.index, updatedLayout);

                        Navigator.of(context).pop();
                      }
                    },
                    child: const Text('Save Changes'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
