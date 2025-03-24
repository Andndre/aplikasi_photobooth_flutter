import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/layouts.dart';
import 'package:path/path.dart' as path;

class RenderLayoutWithPhotos extends StatefulWidget {
  final Layouts layout;

  const RenderLayoutWithPhotos({super.key, required this.layout});

  @override
  State<RenderLayoutWithPhotos> createState() => _RenderLayoutWithPhotosState();
}

class _RenderLayoutWithPhotosState extends State<RenderLayoutWithPhotos> {
  // Map of camera element ID to selected photo path
  final Map<String, String> _selectedPhotos = {};
  bool _isRendering = false;
  String? _renderedImagePath;

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
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${tempDir.path}/rendered_layout_$timestamp.jpg';

      // Extract just the photo paths in the order of camera elements
      final photoPaths =
          _cameraElements
              .map((element) => _selectedPhotos[element.id])
              .where((path) => path != null)
              .cast<String>()
              .toList();

      // Use the layout's exportAsImage method
      final outputFile = await widget.layout.exportAsImage(
        exportPath: outputPath,
        photoFilePaths: photoPaths,
        resolutionMultiplier: 1.5, // Higher quality for preview
      );

      if (outputFile != null) {
        setState(() {
          _renderedImagePath = outputFile.path;
        });
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

  // Method to save the rendered image
  Future<void> _saveRenderedImage() async {
    if (_renderedImagePath == null) return;

    try {
      final result = await FilePicker.platform.getDirectoryPath();
      if (result != null) {
        final fileName =
            'composite_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final outputPath = path.join(result, fileName);

        await File(_renderedImagePath!).copy(outputPath);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image saved to: $outputPath')),
          );
        }
      }
    } catch (e) {
      print('Error saving image: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving image: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Render Layout with Photos'),
        actions: [
          if (_renderedImagePath != null)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveRenderedImage,
              tooltip: 'Save Image',
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top section - Photo Selection
          Expanded(
            flex: 1,
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

          // Bottom section - Rendered Preview
          Expanded(
            flex: 2,
            child: Card(
              margin: const EdgeInsets.all(16),
              child:
                  _isRendering
                      ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Rendering composite image...'),
                          ],
                        ),
                      )
                      : _renderedImagePath != null
                      ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rendered Composite',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Center(
                                child: InteractiveViewer(
                                  child: Image.file(
                                    File(_renderedImagePath!),
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                      : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.image_not_supported,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No rendered image yet',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Select photos and click "Render Composite"',
                              style: Theme.of(context).textTheme.bodyMedium,
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
