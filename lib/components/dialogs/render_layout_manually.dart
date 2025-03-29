import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:photobooth/models/layout_model.dart';
import 'package:photobooth/models/renderables/camera_element.dart';
import 'package:photobooth/models/renderables/renderer.dart';

class RenderLayoutManually extends StatefulWidget {
  final LayoutModel layout;

  const RenderLayoutManually({super.key, required this.layout});

  @override
  State<RenderLayoutManually> createState() => _RenderLayoutManuallyState();
}

class _RenderLayoutManuallyState extends State<RenderLayoutManually> {
  // Map of camera element ID to selected photo path
  final Map<String, String> _selectedPhotos = {};
  bool _isRendering = false;
  double _resolutionMultiplier = 1.0;
  String? _outputPath;

  // List of all camera elements in the layout
  late final List<CameraElement> _cameraElements;

  @override
  void initState() {
    super.initState();
    _cameraElements =
        widget.layout.elements
            .where((e) => e.type == 'camera')
            .map((e) => e as CameraElement)
            .toList();
  }

  // Method to select a photo for a specific camera element
  Future<void> _selectPhotoForCamera(String cameraId) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null &&
          result.files.isNotEmpty &&
          result.files.first.path != null) {
        setState(() {
          _selectedPhotos[cameraId] = result.files.first.path!;
        });
      }
    } catch (e) {
      print('Error selecting photo: $e');
    }
  }

  // Method to render the composite image
  Future<void> _renderComposite() async {
    if (_selectedPhotos.length < _cameraElements.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select photos for all ${_cameraElements.length} camera spots',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isRendering = true;
    });

    try {
      // Create a directory for the rendered image
      final tempDir = await getTemporaryDirectory();
      final fileName = 'composite_${DateTime.now().millisecondsSinceEpoch}.jpg';
      String outputPath;
      if (_outputPath == null) {
        outputPath = '${tempDir.path}/$fileName';
      } else {
        outputPath = path.join(_outputPath!, fileName);
      }

      // Extract just the photo paths in the order of camera elements
      final photoPaths = _selectedPhotos.values.toList();

      print("Photo paths: $photoPaths");

      final outputFile = await Renderer.exportLayoutWithImages(
        layout: widget.layout,
        exportPath: outputPath,
        resolutionMultiplier: 1,
        filePaths: photoPaths,
      );

      if (outputFile != null) {
        setState(() {});
      }
      if (context.mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image saved to: $outputPath'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () async {
                File(outputPath).openRead();
              },
            ),
          ),
        );
      }
    } catch (e) {
      print('Error rendering composite: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rendering composite: $e')),
        );
      }
    } finally {
      setState(() {
        _isRendering = false;
      });
    }
  }

  Future<void> _selectOutputPath() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      setState(() {
        _outputPath = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Render Layout with Photos')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top section - Photo Selection
          Expanded(
            flex: 2,
            child: Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Photos for Layout',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose photos for each camera slot in the layout',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Output Path: '),
                        Expanded(
                          child: Text(
                            _outputPath == null
                                ? 'Select a directory'
                                : _outputPath!,
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.folder),
                          onPressed: _selectOutputPath,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Resolution: '),
                        DropdownButton<double>(
                          value: _resolutionMultiplier,
                          onChanged: (double? newValue) {
                            setState(() {
                              _resolutionMultiplier = newValue!;
                            });
                          },
                          items:
                              <double>[
                                1,
                                1.5,
                                2,
                                3,
                                4,
                              ].map<DropdownMenuItem<double>>((double value) {
                                return DropdownMenuItem<double>(
                                  value: value,
                                  child: Text('${value}x'),
                                );
                              }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _cameraElements.length,
                        itemBuilder: (context, index) {
                          final camera = _cameraElements[index];
                          final hasPhoto = _selectedPhotos.containsKey(
                            camera.id,
                          );

                          return ListTile(
                            leading:
                                hasPhoto
                                    ? ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.file(
                                        File(_selectedPhotos[camera.id]!),
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                    : const Icon(Icons.camera_alt),
                            title: Text(camera.label),
                            subtitle: Text(
                              hasPhoto
                                  ? 'Photo selected: ${path.basename(_selectedPhotos[camera.id]!)}'
                                  : 'No photo selected',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_photo_alternate),
                              onPressed: () => _selectPhotoForCamera(camera.id),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.image),
                        label: const Text('Render Composite'),
                        onPressed: _isRendering ? null : _renderComposite,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
