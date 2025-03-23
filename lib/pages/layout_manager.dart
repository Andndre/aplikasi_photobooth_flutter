import 'package:aplikasi_photobooth_flutter/pages/layout_editor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/layouts.dart';
import '../models/layouts.dart';
import 'dart:io';
import 'dart:math';

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
  final Layouts layout;
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
                        // Navigate directly to the layout editor
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (context) => LayoutEditor(
                                  layout: layout,
                                  layoutIndex: index,
                                ),
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

class CreateLayoutDialog extends StatefulWidget {
  const CreateLayoutDialog({super.key});

  @override
  State<CreateLayoutDialog> createState() => CreateLayoutDialogState();
}

class CreateLayoutDialogState extends State<CreateLayoutDialog> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  int _width = 1200; // Default to 4R size
  int _height = 1800;
  bool _useCustomResolution = false;
  bool _isLandscape = false; // New state to track orientation

  // Predefined templates - Standard photo paper sizes at 300 DPI
  final List<Map<String, dynamic>> _templates = [
    {
      'name': '4R',
      'description': '4 x 6 inches',
      'width': 1200, // 4 inches x 300 DPI
      'height': 1800, // 6 inches x 300 DPI
      'icon': Icons.photo_size_select_actual,
    },
    {
      'name': '5R',
      'description': '5 x 7 inches',
      'width': 1500, // 5 inches x 300 DPI
      'height': 2100, // 7 inches x 300 DPI
      'icon': Icons.photo_size_select_actual,
    },
    {
      'name': '6R',
      'description': '6 x 8 inches',
      'width': 1800, // 6 inches x 300 DPI
      'height': 2400, // 8 inches x 300 DPI
      'icon': Icons.photo_size_select_actual,
    },
    {
      'name': '8R',
      'description': '8 x 10 inches',
      'width': 2400, // 8 inches x 300 DPI
      'height': 3000, // 10 inches x 300 DPI
      'icon': Icons.photo_size_select_actual,
    },
    {
      'name': 'S8R',
      'description': '8 x 12 inches',
      'width': 2400, // 8 inches x 300 DPI
      'height': 3600, // 12 inches x 300 DPI
      'icon': Icons.photo_size_select_actual,
    },
    {
      'name': '10R',
      'description': '10 x 12 inches',
      'width': 3000, // 10 inches x 300 DPI
      'height': 3600, // 12 inches x 300 DPI
      'icon': Icons.photo_size_select_actual,
    },
    {
      'name': '12R',
      'description': '12 x 16 inches',
      'width': 3600, // 12 inches x 300 DPI
      'height': 4800, // 16 inches x 300 DPI
      'icon': Icons.photo_size_select_large,
    },
    {
      'name': 'A4',
      'description': '8.3 x 11.7 inches',
      'width': 2480, // 8.3 inches x 300 DPI (rounded)
      'height': 3508, // 11.7 inches x 300 DPI (rounded)
      'icon': Icons.description,
    },
    {
      'name': 'Square',
      'description': '8 x 8 inches',
      'width': 2400, // 8 inches x 300 DPI
      'height': 2400, // 8 inches x 300 DPI
      'icon': Icons.crop_square,
    },
    {
      'name': 'Portrait',
      'description': '8 x 10 inches',
      'width': 2400, // 8 inches x 300 DPI
      'height': 3000, // 10 inches x 300 DPI
      'icon': Icons.crop_portrait,
    },
    {
      'name': 'Landscape',
      'description': '10 x 8 inches',
      'width': 3000, // 10 inches x 300 DPI
      'height': 2400, // 8 inches x 300 DPI
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
        // Apply the template dimensions based on orientation
        if (_isLandscape) {
          _width = template['height'];
          _height = template['width'];
        } else {
          _width = template['width'];
          _height = template['height'];
        }
        _widthController.text = _width.toString();
        _heightController.text = _height.toString();
      });
    }
  }

  // New method to toggle orientation
  void _toggleOrientation() {
    if (!_useCustomResolution) {
      setState(() {
        _isLandscape = !_isLandscape;
        // Swap width and height
        final temp = _width;
        _width = _height;
        _height = temp;
        // Update controllers
        _widthController.text = _width.toString();
        _heightController.text = _height.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 1000;
    final isLowHeight = screenSize.height < 700;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      // Set dialog size based on screen size
      child: Container(
        width:
            isSmallScreen
                ? screenSize.width * 0.95
                : min(screenSize.width * 0.85, 1200.0),
        height:
            isSmallScreen
                ? screenSize.height * 0.95
                : min(screenSize.height * 0.85, 800.0),
        padding: EdgeInsets.all(isSmallScreen || isLowHeight ? 12.0 : 24.0),
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
                    style:
                        isLowHeight
                            ? Theme.of(context).textTheme.titleLarge
                            : Theme.of(context).textTheme.headlineSmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              SizedBox(height: isLowHeight ? 8.0 : 16.0),

              // Main content area - adapt layout based on screen size
              Expanded(
                child:
                    isSmallScreen || isLowHeight
                        ? _buildSmallScreenLayout()
                        : _buildWideScreenLayout(),
              ),

              SizedBox(height: isLowHeight ? 8.0 : 16.0),

              // Dialog buttons
              _buildDialogButtons(),
            ],
          ),
        ),
      ),
    );
  }

  // Layout for wide screens - side by side template and details
  Widget _buildWideScreenLayout() {
    final screenSize = MediaQuery.of(context).size;
    final isLowHeight = screenSize.height < 700;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side - Template selection
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _buildTemplateSelector(isLowHeight: isLowHeight),
          ),
        ),

        // Vertical divider
        Container(width: 1, color: Theme.of(context).dividerColor),

        // Right side - Layout details form
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: SingleChildScrollView(
              child: _buildLayoutDetailsForm(isLowHeight: isLowHeight),
            ),
          ),
        ),
      ],
    );
  }

  // Layout for small screens - stacked template and details
  Widget _buildSmallScreenLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top part - Layout details form (more important for input)
        _buildCompactLayoutDetailsForm(),

        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 8),

        // Label for templates
        Text(
          'Choose a Template',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Standard photo paper sizes at 300 DPI',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),

        // Bottom part - Template grid (scrollable)
        Expanded(child: _buildCompactTemplateSelector()),
      ],
    );
  }

  // Template selector for small screens - more compact display
  Widget _buildCompactTemplateSelector() {
    return Opacity(
      opacity: _useCustomResolution ? 0.5 : 1.0,
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // Fewer columns for small screens
          childAspectRatio: 1.2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _templates.length,
        itemBuilder: (context, index) {
          final template = _templates[index];
          // Fix template selection highlighting by checking both orientations
          final bool isSelected =
              !_useCustomResolution &&
              ((_width == template['width'] && _height == template['height']) ||
                  (_isLandscape &&
                      _width == template['height'] &&
                      _height == template['width']));

          return InkWell(
            onTap:
                _useCustomResolution ? null : () => _selectTemplate(template),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    template['icon'] as IconData,
                    size: 24,
                    color:
                        isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    template['name'] as String,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : null,
                      fontSize: 14,
                      color:
                          isSelected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    template['description'] as String,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Compact layout details form for small screens
  Widget _buildCompactLayoutDetailsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Layout Name',
            border: OutlineInputBorder(),
            filled: true,
            isDense: true,
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
        const SizedBox(height: 12),

        // Custom resolution controls
        Row(
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Checkbox(
                value: _useCustomResolution,
                onChanged: (value) {
                  setState(() {
                    _useCustomResolution = value ?? false;
                  });
                },
              ),
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

        // Show either custom resolution fields or selected dimensions
        if (_useCustomResolution) ...[
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
                    isDense: true,
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
                    isDense: true,
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodyMedium,
                        children: [
                          const TextSpan(text: 'Selected: '),
                          TextSpan(
                            text: '$_width x $_height px',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    // Replace with two separate buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildOrientationButton(false, compact: true),
                        const SizedBox(width: 4),
                        _buildOrientationButton(true, compact: true),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // Helper method for orientation button
  Widget _buildOrientationButton(bool landscape, {bool compact = false}) {
    final isSelected = _isLandscape == landscape;
    final buttonSize = compact ? const Size(36, 30) : const Size(44, 36);

    // Define tooltip text based on orientation
    final tooltipText = landscape ? 'Landscape' : 'Portrait';

    return Tooltip(
      message: tooltipText,
      child: Material(
        color:
            isSelected
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap:
              _useCustomResolution
                  ? null
                  : () {
                    if (_isLandscape != landscape) {
                      _toggleOrientation();
                    }
                  },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: buttonSize.height,
            width: buttonSize.width,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color:
                    isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                width: 2,
              ),
            ),
            child: Icon(
              landscape ? Icons.crop_landscape : Icons.crop_portrait,
              size: compact ? 16 : 20,
              color:
                  isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateSelector({bool isLowHeight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose a Template',
          style:
              isLowHeight
                  ? Theme.of(context).textTheme.titleMedium
                  : Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Standard photo paper sizes at 300 DPI',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Opacity(
            opacity: _useCustomResolution ? 0.5 : 1.0,
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isLowHeight ? 4 : 3,
                childAspectRatio: isLowHeight ? 1.0 : 0.8,
                crossAxisSpacing: isLowHeight ? 8 : 16,
                mainAxisSpacing: isLowHeight ? 8 : 16,
              ),
              itemCount: _templates.length,
              itemBuilder: (context, index) {
                final template = _templates[index];
                // Fix template selection highlighting by checking both orientations
                final bool isSelected =
                    !_useCustomResolution &&
                    ((_width == template['width'] &&
                            _height == template['height']) ||
                        (_isLandscape &&
                            _width == template['height'] &&
                            _height == template['width']));

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
                              : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    padding: EdgeInsets.all(isLowHeight ? 8 : 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          template['icon'] as IconData,
                          size: isLowHeight ? 32 : 48,
                          color:
                              isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                        ),
                        SizedBox(height: isLowHeight ? 8 : 16),
                        Text(
                          template['name'] as String,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : null,
                            fontSize: isLowHeight ? 14 : 18,
                            color:
                                isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (!isLowHeight)
                          Text(
                            template['description'] as String,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (!isLowHeight) const SizedBox(height: 4),
                        Text(
                          '${template['width']} x ${template['height']} px',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontSize: isLowHeight ? 10 : null),
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

  Widget _buildLayoutDetailsForm({bool isLowHeight = false}) {
    final descriptionTextStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Layout Details',
          style:
              isLowHeight
                  ? Theme.of(context).textTheme.titleMedium
                  : Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: isLowHeight ? 16 : 24),

        // Layout name
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Layout Name',
            border: OutlineInputBorder(),
            filled: true,
            isDense: true,
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
        SizedBox(height: isLowHeight ? 16 : 24),

        // Custom resolution checkbox
        Row(
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Checkbox(
                value: _useCustomResolution,
                onChanged: (value) {
                  setState(() {
                    _useCustomResolution = value ?? false;
                  });
                },
              ),
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
        SizedBox(height: isLowHeight ? 12 : 16),

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
                    isDense: true,
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
                    isDense: true,
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
          // Display selected template dimensions with orientation buttons
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Selected Resolution'),
                    // Orientation toggle buttons
                    Row(
                      children: [
                        const Text(
                          'Orientation: ',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            _buildOrientationButton(false),
                            const SizedBox(width: 8),
                            _buildOrientationButton(true),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$_width x $_height pixels (300 DPI)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (!isLowHeight) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${(_width / 300).toStringAsFixed(1)} x ${(_height / 300).toStringAsFixed(1)} inches',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    '${(_width / 118.11).toStringAsFixed(1)} x ${(_height / 118.11).toStringAsFixed(1)} cm',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ],

        SizedBox(height: isLowHeight ? 16 : 24),
        Text(
          'Base image and photo spots can be configured after creating the layout.',
          style: descriptionTextStyle,
        ),
      ],
    );
  }

  Widget _buildDialogButtons() {
    return Row(
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
          onPressed: () => _createAndNavigateToEditor(context),
          child: const Text('Create Layout'),
        ),
      ],
    );
  }

  Future<void> _createAndNavigateToEditor(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Create a new layout with the specified dimensions
      final newLayout = Layouts(
        name: _name,
        id: 0, // ID will be set by the provider
        width: _width,
        height: _height,
        backgroundColor: '#FFFFFF',
        elements: [], // Empty elements list for new layout
      );

      final layoutsProvider = Provider.of<LayoutsProvider>(
        context,
        listen: false,
      );

      await layoutsProvider.addLayout(newLayout);

      // Find the index of the newly added layout
      final index = layoutsProvider.layouts.length - 1;

      if (context.mounted) {
        // Close dialog and navigate to editor
        Navigator.of(context).pop();

        // Navigate to layout editor
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (context) => LayoutEditor(
                  layout: layoutsProvider.layouts[index],
                  layoutIndex: index,
                ),
          ),
        );
      }
    }
  }
}
