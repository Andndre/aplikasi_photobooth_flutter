import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:photobooth/components/photo_preset/before_after_preview.dart';
import 'package:photobooth/components/photo_preset/preset_list.dart';
import 'package:photobooth/components/photo_preset/settings_panel.dart';
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
  final Map<String, double?> _tempValues = {};

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

  // Add detail section handlers
  void _updateSharpness(double value) {
    setState(() {
      _tempValues['sharpness'] = value;
    });
  }

  void _updateDetail(double value) {
    setState(() {
      _tempValues['detail'] = value;
    });
  }

  void _updateNoiseReduction(double value) {
    setState(() {
      _tempValues['noiseReduction'] = value;
    });
  }

  // Add Color Grading handlers
  void _updateShadowsColor(Color color) {
    setState(() {
      _selectedPreset = _selectedPreset!.copyWith(shadowsColor: color);
    });
  }

  void _updateShadowsIntensity(double value) {
    setState(() {
      _tempValues['shadowsIntensity'] = value;
    });
  }

  void _updateMidtonesColor(Color color) {
    setState(() {
      _selectedPreset = _selectedPreset!.copyWith(midtonesColor: color);
    });
  }

  void _updateMidtonesIntensity(double value) {
    setState(() {
      _tempValues['midtonesIntensity'] = value;
    });
  }

  void _updateHighlightsColor(Color color) {
    setState(() {
      _selectedPreset = _selectedPreset!.copyWith(highlightsColor: color);
    });
  }

  void _updateHighlightsIntensity(double value) {
    setState(() {
      _tempValues['highlightsIntensity'] = value;
    });
  }

  void _updateColorBalance(double value) {
    setState(() {
      _tempValues['colorBalance'] = value;
    });
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
                  PresetList(
                    presets: presetProvider.savedPresets,
                    activePreset: presetProvider.activePreset,
                    selectedPreset: _selectedPreset,
                    onPresetSelected: (preset) {
                      setState(() {
                        _selectedPreset = preset;
                        _isEditing = false;
                        // Reset temp values
                        _resetTempValues();
                      });
                      _loadSampleImage();
                    },
                    onPresetDelete:
                        (presetId) => _deletePreset(context, presetId),
                  ),

                  // Center: Before/After preview images in column layout
                  if (_selectedPreset != null)
                    Expanded(
                      flex: 2, // Take more space for the preview images
                      child: BeforeAfterPreview(
                        currentSampleImage: _currentSampleImage,
                        processedImagePreview: _processedImagePreview,
                      ),
                    ),

                  // Right sidebar: Settings panel with scrolling
                  if (_selectedPreset != null)
                    SizedBox(
                      width: 300, // Fixed width for settings panel
                      child: SettingsPanel(
                        preset: _selectedPreset!,
                        isEditing: _isEditing,
                        presetProvider: presetProvider,
                        onPresetUpdated: (preset) {
                          setState(() {
                            _selectedPreset = preset;
                          });
                        },
                        onUpdatePreview: _updateProcessedPreview,
                        onPickColor: _pickColor,
                        eventId: widget.eventId,
                        tempValues: _tempValues,
                        onCancel: () {
                          setState(() {
                            // Reset to original values
                            _selectedPreset = presetProvider.savedPresets
                                .firstWhere(
                                  (p) => p.id == _selectedPreset!.id,
                                  orElse: () => PresetModel.defaultPreset(),
                                );
                            _isEditing = false;
                            _resetTempValues();
                          });
                          _loadSampleImage();
                        },
                        // Basic sliders
                        updateBrightness: (value) {
                          setState(() {
                            _tempValues['brightness'] = value;
                          });
                        },
                        updateContrast: (value) {
                          setState(() {
                            _tempValues['contrast'] = value;
                          });
                        },
                        updateSaturation: (value) {
                          setState(() {
                            _tempValues['saturation'] = value;
                          });
                        },
                        updateBorderWidth: (value) {
                          setState(() {
                            _tempValues['borderWidth'] = value;
                          });
                        },
                        updateTemperature: (value) {
                          setState(() {
                            _tempValues['temperature'] = value;
                          });
                        },
                        updateTint: (value) {
                          setState(() {
                            _tempValues['tint'] = value;
                          });
                        },
                        updateExposure: (value) {
                          setState(() {
                            _tempValues['exposure'] = value;
                          });
                        },
                        updateHighlights: (value) {
                          setState(() {
                            _tempValues['highlights'] = value;
                          });
                        },
                        updateShadows: (value) {
                          setState(() {
                            _tempValues['shadows'] = value;
                          });
                        },
                        updateWhites: (value) {
                          setState(() {
                            _tempValues['whites'] = value;
                          });
                        },
                        updateBlacks: (value) {
                          setState(() {
                            _tempValues['blacks'] = value;
                          });
                        },
                        updateBlackAndWhite: (value) {
                          setState(() {
                            _selectedPreset = _selectedPreset!.copyWith(
                              blackAndWhite: value,
                            );
                          });
                        },
                        // Color Mixer sliders
                        updateRedHue: (value) {
                          setState(() {
                            _tempValues['redHue'] = value;
                          });
                        },
                        updateRedSaturation: (value) {
                          setState(() {
                            _tempValues['redSaturation'] = value;
                          });
                        },
                        updateRedLuminance: (value) {
                          setState(() {
                            _tempValues['redLuminance'] = value;
                          });
                        },
                        updateGreenHue: (value) {
                          setState(() {
                            _tempValues['greenHue'] = value;
                          });
                        },
                        updateGreenSaturation: (value) {
                          setState(() {
                            _tempValues['greenSaturation'] = value;
                          });
                        },
                        updateGreenLuminance: (value) {
                          setState(() {
                            _tempValues['greenLuminance'] = value;
                          });
                        },
                        updateBlueHue: (value) {
                          setState(() {
                            _tempValues['blueHue'] = value;
                          });
                        },
                        updateBlueSaturation: (value) {
                          setState(() {
                            _tempValues['blueSaturation'] = value;
                          });
                        },
                        updateBlueLuminance: (value) {
                          setState(() {
                            _tempValues['blueLuminance'] = value;
                          });
                        },
                        pickSampleImage: _pickSampleImage,

                        // Detail section callbacks
                        updateSharpness: _updateSharpness,
                        updateDetail: _updateDetail,
                        updateNoiseReduction: _updateNoiseReduction,

                        // Add color grading handlers
                        updateShadowsColor: _updateShadowsColor,
                        updateShadowsIntensity: _updateShadowsIntensity,
                        updateMidtonesColor: _updateMidtonesColor,
                        updateMidtonesIntensity: _updateMidtonesIntensity,
                        updateHighlightsColor: _updateHighlightsColor,
                        updateHighlightsIntensity: _updateHighlightsIntensity,
                        updateColorBalance: _updateColorBalance,
                      ),
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
    _tempValues.clear();
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
