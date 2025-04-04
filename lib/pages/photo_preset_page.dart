import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:photobooth/models/preset_model.dart';
import 'package:photobooth/providers/preset_provider.dart';
import 'package:photobooth/services/image_processor.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class PhotoPresetPage extends StatefulWidget {
  // Optional event ID to apply preset directly to that event
  final String? eventId;

  const PhotoPresetPage({super.key, this.eventId});

  @override
  State<PhotoPresetPage> createState() => _PhotoPresetPageState();
}

class _PhotoPresetPageState extends State<PhotoPresetPage> {
  final uuid = const Uuid();
  PresetModel? _selectedPreset;
  bool _isEditing = false;
  File? _currentSampleImage;
  Uint8List? _processedImagePreview;
  bool _isProcessingImage = false;

  // Temporary values for sliders
  double? _tempBrightness;
  double? _tempContrast;
  double? _tempSaturation;
  double? _tempBorderWidth;

  // Add temporary values for new sliders
  double? _tempTemperature;
  double? _tempTint;
  double? _tempExposure;
  double? _tempHighlights;
  double? _tempShadows;
  double? _tempWhites;
  double? _tempBlacks;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<PresetProvider>(context, listen: false);
      if (provider.activePreset != null) {
        setState(() {
          _selectedPreset = provider.activePreset;
          _loadSampleImage();
        });
      }
    });
  }

  Future<void> _loadSampleImage() async {
    if (_selectedPreset == null) return;

    setState(() {
      _isProcessingImage = true;
    });

    try {
      // Check if the preset has a sample image
      if (_selectedPreset!.sampleImagePath != null) {
        final imageFile = File(_selectedPreset!.sampleImagePath!);
        if (await imageFile.exists()) {
          _currentSampleImage = imageFile;
          await _updateProcessedPreview();
        } else {
          // If image doesn't exist, use placeholder
          _currentSampleImage = await ImageProcessor.getPlaceholderImage();
        }
      } else {
        // Use placeholder if no sample image
        _currentSampleImage = await ImageProcessor.getPlaceholderImage();
      }

      if (_currentSampleImage != null) {
        await _updateProcessedPreview();
      }
    } catch (e) {
      print('Error loading sample image: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingImage = false;
        });
      }
    }
  }

  Future<void> _updateProcessedPreview() async {
    if (_currentSampleImage == null || _selectedPreset == null) {
      setState(() {
        _processedImagePreview = null;
      });
      return;
    }

    setState(() {
      _isProcessingImage = true;
    });

    try {
      final processedBytes = await ImageProcessor.generatePreview(
        _currentSampleImage!,
        _selectedPreset!,
      );

      if (mounted) {
        setState(() {
          _processedImagePreview = processedBytes;
        });
      }
    } catch (e) {
      print('Error updating preview: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingImage = false;
        });
      }
    }
  }

  Future<void> _pickSampleImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);

        // Copy the file to the app's documents directory for persistence
        final docDir = await getApplicationDocumentsDirectory();
        final sampleDir = Directory('${docDir.path}/preset_samples');
        await sampleDir.create(recursive: true);

        final fileName = '${uuid.v4()}${path.extension(file.path)}';
        final savedFile = await file.copy('${sampleDir.path}/$fileName');

        setState(() {
          _currentSampleImage = savedFile;
        });

        if (_isEditing && _selectedPreset != null) {
          setState(() {
            _selectedPreset = _selectedPreset!.copyWith(
              sampleImagePath: savedFile.path,
            );
          });
        }

        await _updateProcessedPreview();
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error selecting image: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Presets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add New Preset',
            onPressed: () => _createNewPreset(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          Consumer<PresetProvider>(
            builder: (context, presetProvider, child) {
              if (presetProvider.savedPresets.isEmpty) {
                return const Center(
                  child: Text(
                    'No presets available. Create one to get started.',
                  ),
                );
              }

              return Row(
                children: [
                  // Left sidebar with preset list
                  SizedBox(
                    width: 200, // Reduced width for preset list
                    child: Card(
                      margin: EdgeInsets.zero,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                      child: ListView.builder(
                        itemCount: presetProvider.savedPresets.length,
                        itemBuilder: (context, index) {
                          final preset = presetProvider.savedPresets[index];
                          final isActive =
                              preset.id == presetProvider.activePreset?.id;

                          return ListTile(
                            title: Text(preset.name),
                            selected: _selectedPreset?.id == preset.id,
                            leading:
                                isActive
                                    ? const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    )
                                    : const Icon(Icons.photo_filter),
                            trailing:
                                preset.id != 'default'
                                    ? IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed:
                                          () =>
                                              _deletePreset(context, preset.id),
                                    )
                                    : null,
                            onTap: () {
                              setState(() {
                                _selectedPreset = preset;
                                _isEditing = false;
                                // Reset temp values
                                _resetTempValues();
                              });
                              _loadSampleImage();
                            },
                          );
                        },
                      ),
                    ),
                  ),

                  // Center: Before/After preview images in column layout
                  if (_selectedPreset != null)
                    Expanded(
                      flex: 2, // Take more space for the preview images
                      child: _buildVerticalBeforeAfterPreview(),
                    ),

                  // Right sidebar: Settings panel with scrolling
                  if (_selectedPreset != null)
                    SizedBox(
                      width: 300, // Fixed width for settings panel
                      child: _buildSettingsPanel(presetProvider),
                    ),
                ],
              );
            },
          ),

          // Processing overlay when processing is in progress
          if (_isProcessingImage)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      floatingActionButton:
          _selectedPreset != null && !_isEditing
              ? FloatingActionButton(
                onPressed: () {
                  setState(() {
                    _isEditing = true;
                    // Reset temp values when starting edit
                    _resetTempValues();
                  });
                },
                child: const Icon(Icons.edit),
              )
              : null,
    );
  }

  // Reset temporary slider values
  void _resetTempValues() {
    if (_selectedPreset != null) {
      _tempBrightness = _selectedPreset!.brightness;
      _tempContrast = _selectedPreset!.contrast;
      _tempSaturation = _selectedPreset!.saturation;
      _tempBorderWidth = _selectedPreset!.borderWidth;

      // Reset new temp values
      _tempTemperature = _selectedPreset!.temperature;
      _tempTint = _selectedPreset!.tint;
      _tempExposure = _selectedPreset!.exposure;
      _tempHighlights = _selectedPreset!.highlights;
      _tempShadows = _selectedPreset!.shadows;
      _tempWhites = _selectedPreset!.whites;
      _tempBlacks = _selectedPreset!.blacks;
    } else {
      _tempBrightness = null;
      _tempContrast = null;
      _tempSaturation = null;
      _tempBorderWidth = null;

      // Reset new temp values to null
      _tempTemperature = null;
      _tempTint = null;
      _tempExposure = null;
      _tempHighlights = null;
      _tempShadows = null;
      _tempWhites = null;
      _tempBlacks = null;
    }
  }

  // New method for before/after preview in vertical layout
  Widget _buildVerticalBeforeAfterPreview() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxHeight = constraints.maxHeight;
          final imageHeight =
              (maxHeight - 16) / 2; // Divide height for two images

          return Column(
            children: [
              // Original image (top)
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child:
                      _currentSampleImage != null
                          ? Image.file(
                            _currentSampleImage!,
                            fit: BoxFit.contain,
                          )
                          : const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              size: 50,
                              color: Colors.grey,
                            ),
                          ),
                ),
              ),

              const SizedBox(height: 16),

              // Processed image (bottom)
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child:
                      _processedImagePreview != null
                          ? Image.memory(
                            _processedImagePreview!,
                            fit: BoxFit.contain,
                          )
                          : _currentSampleImage != null
                          ? Image.file(
                            _currentSampleImage!,
                            fit: BoxFit.contain,
                            color: Colors.grey.withOpacity(0.5),
                            colorBlendMode: BlendMode.saturation,
                          )
                          : const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              size: 50,
                              color: Colors.grey,
                            ),
                          ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // New method for settings panel in the right sidebar
  Widget _buildSettingsPanel(PresetProvider presetProvider) {
    final preset = _selectedPreset!;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          left: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _isEditing ? 'Edit Preset' : preset.name,
                    style: Theme.of(context).textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!_isEditing)
                  IconButton(
                    icon: const Icon(Icons.check_circle),
                    tooltip: 'Set as Active',
                    onPressed: () {
                      presetProvider.setActivePreset(preset.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${preset.name} set as active preset'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
              ],
            ),

            if (_isEditing)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _pickSampleImage,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text('Change Sample Image'),
                      ),
                    ),
                  ],
                ),
              ),

            // Preset name edit field in edit mode
            if (_isEditing) ...[
              TextFormField(
                initialValue: preset.name,
                decoration: const InputDecoration(
                  labelText: 'Preset Name',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _selectedPreset = preset.copyWith(name: value);
                  });
                },
              ),
              const SizedBox(height: 16),
            ],

            // Collapsible Basic section containing all adjustments
            _buildCollapsibleSection(
              title: 'Basic',
              initiallyExpanded: true,
              children: [
                // White Balance subsection
                _buildSubsectionHeader('White Balance'),
                _buildSliderSetting(
                  'Temperature',
                  _tempTemperature ?? preset.temperature,
                  -1.0,
                  1.0,
                  (value) {
                    setState(() {
                      _tempTemperature = value;
                    });
                  },
                  (value) {
                    setState(() {
                      _selectedPreset = preset.copyWith(temperature: value);
                      _tempTemperature = null;
                    });
                    _updateProcessedPreview();
                  },
                  _isEditing,
                  leftLabel: 'Cool',
                  rightLabel: 'Warm',
                ),

                _buildSliderSetting(
                  'Tint',
                  _tempTint ?? preset.tint,
                  -1.0,
                  1.0,
                  (value) {
                    setState(() {
                      _tempTint = value;
                    });
                  },
                  (value) {
                    setState(() {
                      _selectedPreset = preset.copyWith(tint: value);
                      _tempTint = null;
                    });
                    _updateProcessedPreview();
                  },
                  _isEditing,
                  leftLabel: 'Green',
                  rightLabel: 'Magenta',
                ),

                // Tone subsection
                _buildSubsectionHeader('Tone'),
                _buildSliderSetting(
                  'Exposure',
                  _tempExposure ?? preset.exposure,
                  -1.0,
                  1.0,
                  (value) {
                    setState(() {
                      _tempExposure = value;
                    });
                  },
                  (value) {
                    setState(() {
                      _selectedPreset = preset.copyWith(exposure: value);
                      _tempExposure = null;
                    });
                    _updateProcessedPreview();
                  },
                  _isEditing,
                ),

                _buildSliderSetting(
                  'Highlights',
                  _tempHighlights ?? preset.highlights,
                  -1.0,
                  1.0,
                  (value) {
                    setState(() {
                      _tempHighlights = value;
                    });
                  },
                  (value) {
                    setState(() {
                      _selectedPreset = preset.copyWith(highlights: value);
                      _tempHighlights = null;
                    });
                    _updateProcessedPreview();
                  },
                  _isEditing,
                  leftLabel: 'Increase',
                  rightLabel: 'Reduce',
                ),

                _buildSliderSetting(
                  'Shadows',
                  _tempShadows ?? preset.shadows,
                  -1.0,
                  1.0,
                  (value) {
                    setState(() {
                      _tempShadows = value;
                    });
                  },
                  (value) {
                    setState(() {
                      _selectedPreset = preset.copyWith(shadows: value);
                      _tempShadows = null;
                    });
                    _updateProcessedPreview();
                  },
                  _isEditing,
                  leftLabel: 'Darker',
                  rightLabel: 'Brighter',
                ),

                _buildSliderSetting(
                  'Whites',
                  _tempWhites ?? preset.whites,
                  -1.0,
                  1.0,
                  (value) {
                    setState(() {
                      _tempWhites = value;
                    });
                  },
                  (value) {
                    setState(() {
                      _selectedPreset = preset.copyWith(whites: value);
                      _tempWhites = null;
                    });
                    _updateProcessedPreview();
                  },
                  _isEditing,
                  leftLabel: 'Reduce',
                  rightLabel: 'Increase',
                ),

                _buildSliderSetting(
                  'Blacks',
                  _tempBlacks ?? preset.blacks,
                  -1.0,
                  1.0,
                  (value) {
                    setState(() {
                      _tempBlacks = value;
                    });
                  },
                  (value) {
                    setState(() {
                      _selectedPreset = preset.copyWith(blacks: value);
                      _tempBlacks = null;
                    });
                    _updateProcessedPreview();
                  },
                  _isEditing,
                  leftLabel: 'Deepen',
                  rightLabel: 'Lighten',
                ),

                // Presence subsection
                _buildSubsectionHeader('Presence'),
                _buildSliderSetting(
                  'Brightness',
                  _tempBrightness ?? preset.brightness,
                  -1.0,
                  1.0,
                  (value) {
                    setState(() {
                      _tempBrightness = value;
                    });
                  },
                  (value) {
                    setState(() {
                      _selectedPreset = preset.copyWith(brightness: value);
                      _tempBrightness = null;
                    });
                    _updateProcessedPreview();
                  },
                  _isEditing,
                ),

                _buildSliderSetting(
                  'Contrast',
                  _tempContrast ?? preset.contrast,
                  -1.0,
                  1.0,
                  (value) {
                    setState(() {
                      _tempContrast = value;
                    });
                  },
                  (value) {
                    setState(() {
                      _selectedPreset = preset.copyWith(contrast: value);
                      _tempContrast = null;
                    });
                    _updateProcessedPreview();
                  },
                  _isEditing,
                ),

                _buildSliderSetting(
                  'Saturation',
                  _tempSaturation ?? preset.saturation,
                  -1.0,
                  1.0,
                  (value) {
                    setState(() {
                      _tempSaturation = value;
                    });
                  },
                  (value) {
                    setState(() {
                      _selectedPreset = preset.copyWith(saturation: value);
                      _tempSaturation = null;
                    });
                    _updateProcessedPreview();
                  },
                  _isEditing,
                ),

                SwitchListTile(
                  title: const Text('Black and White'),
                  subtitle: const Text('Convert image to grayscale'),
                  value: preset.blackAndWhite,
                  onChanged:
                      _isEditing
                          ? (value) {
                            setState(() {
                              _selectedPreset = preset.copyWith(
                                blackAndWhite: value,
                              );
                            });
                            _updateProcessedPreview();
                          }
                          : null,
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Separate collapsible Effects section for border width
            _buildCollapsibleSection(
              title: 'Effects',
              initiallyExpanded: true,
              children: [
                _buildSubsectionHeader('Border'),
                _buildSliderSetting(
                  'Border Width',
                  _tempBorderWidth ?? preset.borderWidth,
                  0.0,
                  10.0,
                  (value) {
                    setState(() {
                      _tempBorderWidth = value;
                    });
                  },
                  (value) {
                    setState(() {
                      _selectedPreset = preset.copyWith(borderWidth: value);
                      _tempBorderWidth = null;
                    });
                    _updateProcessedPreview();
                  },
                  _isEditing,
                ),

                if (_isEditing &&
                    (_tempBorderWidth ?? preset.borderWidth) > 0) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('Border Color: '),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => _pickColor(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: preset.borderColor,
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // Save/Cancel buttons when editing
            if (_isEditing)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        // Reset to original values
                        _selectedPreset = presetProvider.savedPresets
                            .firstWhere(
                              (p) => p.id == preset.id,
                              orElse: () => PresetModel.defaultPreset(),
                            );
                        _isEditing = false;
                        // Reset temp values
                        _resetTempValues();
                      });
                      _loadSampleImage();
                    },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      final updatedPreset = _selectedPreset!;
                      presetProvider.updatePreset(updatedPreset);
                      setState(() {
                        _isEditing = false;
                        // Reset temp values
                        _resetTempValues();
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${updatedPreset.name} updated'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: const Text('Save Changes'),
                  ),
                ],
              ),

            if (widget.eventId != null && !_isEditing)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.sync),
                  label: const Text('Apply to Event'),
                  onPressed: () {
                    // Here we would apply the preset to the event
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${preset.name} applied to event'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // New method for collapsible section
  Widget _buildCollapsibleSection({
    required String title,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withOpacity(0.5),
        ),
      ),
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        iconColor: Theme.of(context).colorScheme.primary,
        textColor: Theme.of(context).colorScheme.primary,
        children: children,
      ),
    );
  }

  // New method for subsection headers inside collapsible sections
  Widget _buildSubsectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.secondary,
              fontSize: 14,
            ),
          ),
          Divider(
            color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
            height: 8,
            thickness: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildSliderSetting(
    String label,
    double value,
    double min,
    double max,
    Function(double) onChanged,
    Function(double) onChangeEnd,
    bool enabled, {
    String? leftLabel,
    String? rightLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text('$label:'), Text(value.toStringAsFixed(2))],
          ),
          if (leftLabel != null || rightLabel != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (leftLabel != null)
                    Text(
                      leftLabel,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    const SizedBox(),
                  if (rightLabel != null)
                    Text(
                      rightLabel,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    const SizedBox(),
                ],
              ),
            ),
          SizedBox(
            height: 30, // Fixed height for slider
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: 100,
              onChanged: enabled ? onChanged : null,
              onChangeEnd: enabled ? onChangeEnd : null,
            ),
          ),
        ],
      ),
    );
  }

  void _pickColor(BuildContext context) async {
    // In a real implementation, you would show a color picker here
    // For now, we'll just use a predefined list of colors
    final colors = [
      Colors.white,
      Colors.black,
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.yellow,
      Colors.purple,
      Colors.orange,
      Colors.pink,
    ];

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Border Color'),
          content: SizedBox(
            width: 300,
            height: 100,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: colors.length,
              itemBuilder: (context, index) {
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedPreset = _selectedPreset!.copyWith(
                        borderColor: colors[index],
                      );
                    });
                    _updateProcessedPreview();
                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors[index],
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _createNewPreset(BuildContext context) {
    final provider = Provider.of<PresetProvider>(context, listen: false);

    final newPreset = provider.createPreset(
      name: 'New Preset',
      addToSaved: true,
      makeActive: false,
    );

    setState(() {
      _selectedPreset = newPreset;
      _isEditing = true;
    });

    _loadSampleImage();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('New preset created'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _deletePreset(BuildContext context, String presetId) {
    final provider = Provider.of<PresetProvider>(context, listen: false);

    // Don't allow deleting the default preset
    if (presetId == 'default') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete the default preset'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Preset?'),
            content: const Text('This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  provider.deletePreset(presetId);
                  if (_selectedPreset?.id == presetId) {
                    setState(() {
                      _selectedPreset = provider.activePreset;
                    });
                    _loadSampleImage();
                  }
                  Navigator.pop(context);
                },
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }
}
