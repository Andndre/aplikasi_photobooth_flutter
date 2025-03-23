import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:widgets_to_image/widgets_to_image.dart';
import '../models/layouts.dart';

/// A utility widget to render a layout with specified photos
class RenderLayoutWithPhotos extends StatefulWidget {
  final Layouts layout;

  const RenderLayoutWithPhotos({super.key, required this.layout});

  @override
  State<RenderLayoutWithPhotos> createState() => _RenderLayoutWithPhotosState();
}

class _RenderLayoutWithPhotosState extends State<RenderLayoutWithPhotos> {
  final List<String> _photoFilePaths = [];
  bool _isExporting = false;
  String? _exportPath;
  String? _errorMessage;
  double _resolutionMultiplier = 1.0;
  bool _includeBackground = true;
  // Replace ScreenshotController with WidgetsToImageController
  final WidgetsToImageController _widgetsToImageController =
      WidgetsToImageController();

  @override
  void initState() {
    super.initState();
    _loadCameraSlots();
  }

  void _loadCameraSlots() {
    // Count how many camera slots exist in the layout
    final cameraElements =
        widget.layout.elements
            .where((e) => e.type == 'camera' && e.isVisible)
            .toList();

    // Initialize with empty paths
    setState(() {
      _photoFilePaths.clear();
      _photoFilePaths.addAll(List.filled(cameraElements.length, ''));
    });
  }

  @override
  Widget build(BuildContext context) {
    // Count camera slots
    final cameraElements =
        widget.layout.elements
            .where((e) => e.type == 'camera' && e.isVisible)
            .cast<CameraElement>()
            .toList();

    return Scaffold(
      appBar: AppBar(title: Text('Render: ${widget.layout.name}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assign Photos to Camera Slots',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Select photos to use for each camera slot in your layout.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // Build camera slot list with photo selection
            Expanded(
              child: ListView.builder(
                itemCount: cameraElements.length,
                itemBuilder: (context, index) {
                  final cameraElement = cameraElements[index];
                  final hasPhoto =
                      index < _photoFilePaths.length &&
                      _photoFilePaths[index].isNotEmpty;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          // Preview of photo or placeholder
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child:
                                hasPhoto
                                    ? ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.file(
                                        File(_photoFilePaths[index]),
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                    : const Icon(
                                      Icons.camera_alt,
                                      color: Colors.grey,
                                      size: 32,
                                    ),
                          ),
                          const SizedBox(width: 16),

                          // Camera slot info and select button
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cameraElement.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Size: ${cameraElement.width.round()} × ${cameraElement.height.round()} px',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: () => _selectPhoto(index),
                                  child: Text(
                                    hasPhoto ? 'Change Photo' : 'Select Photo',
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Delete button if photo exists
                          if (hasPhoto)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _photoFilePaths[index] = '';
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Add preview section above export options
            const Divider(height: 32),
            Text('Preview', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: AspectRatio(
                  aspectRatio: widget.layout.width / widget.layout.height,
                  // Use WidgetsToImage instead of Screenshot
                  child: WidgetsToImage(
                    controller: _widgetsToImageController,
                    child: widget.layout.buildLayoutPreviewWidget(
                      photoFilePaths:
                          _photoFilePaths.where((p) => p.isNotEmpty).toList(),
                      includeBackground: _includeBackground,
                    ),
                  ),
                ),
              ),
            ),

            // Export options section
            const Divider(height: 32),
            Row(
              children: [
                const Text('Resolution:'),
                const SizedBox(width: 16),
                DropdownButton<double>(
                  value: _resolutionMultiplier,
                  items: [
                    DropdownMenuItem(
                      value: 1.0,
                      child: Text(
                        '1x (${widget.layout.width} × ${widget.layout.height})',
                      ),
                    ),
                    const DropdownMenuItem(value: 1.5, child: Text('1.5x')),
                    const DropdownMenuItem(value: 2.0, child: Text('2x')),
                    const DropdownMenuItem(value: 3.0, child: Text('3x')),
                    const DropdownMenuItem(value: 4.0, child: Text('4x')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _resolutionMultiplier = value;
                      });
                    }
                  },
                ),
                const SizedBox(width: 24),
                Checkbox(
                  value: _includeBackground,
                  onChanged: (value) {
                    setState(() {
                      _includeBackground = value ?? true;
                    });
                  },
                ),
                const Text('Include Background'),
              ],
            ),

            // Error message if any
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            // Export button
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _isExporting || !_hasAnyPhotos() ? null : _exportLayout,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child:
                      _isExporting
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('Export Layout'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Check if any photos have been selected
  bool _hasAnyPhotos() {
    return _photoFilePaths.any((path) => path.isNotEmpty);
  }

  // Select a photo for a specific camera slot
  Future<void> _selectPhoto(int index) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          if (index >= _photoFilePaths.length) {
            _photoFilePaths.add(result.files.single.path!);
          } else {
            _photoFilePaths[index] = result.files.single.path!;
          }
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error selecting photo: $e';
      });
    }
  }

  // Updated export method using WidgetsToImage
  Future<void> _exportLayout() async {
    // Choose export location
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose Export Location',
    );

    if (selectedDirectory == null) return;

    // Generate default filename
    String defaultFilename =
        '${widget.layout.name.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.png';
    final exportPath = path.join(selectedDirectory, defaultFilename);

    setState(() {
      _isExporting = true;
      _errorMessage = null;
      _exportPath = exportPath;
    });

    try {
      // Approach 1: Try to use the controller's capture method first
      final bytes = await _widgetsToImageController.capture();

      if (bytes != null) {
        // If we got bytes from the controller, scale them if needed and save to file
        if (_resolutionMultiplier != 1.0) {
          // If scaling is needed, use the model's export method which handles scaling
          final photos = _photoFilePaths.where((p) => p.isNotEmpty).toList();

          final file = await widget.layout.exportAsImage(
            exportPath: exportPath,
            photoFilePaths: photos,
            resolutionMultiplier: _resolutionMultiplier,
            includeBackground: _includeBackground,
          );

          if (file != null && await file.exists()) {
            _showExportSuccess(context);
          } else {
            setState(() {
              _errorMessage = 'Failed to create export file with scaling.';
            });
          }
        } else {
          // No scaling needed, just write bytes to file
          final file = File(exportPath);
          await file.writeAsBytes(bytes);
          _showExportSuccess(context);
        }
      } else {
        // Fallback to model export method if capture returns null
        final photos = _photoFilePaths.where((p) => p.isNotEmpty).toList();

        final file = await widget.layout.exportAsImage(
          exportPath: exportPath,
          photoFilePaths: photos,
          resolutionMultiplier: _resolutionMultiplier,
          includeBackground: _includeBackground,
        );

        if (file != null && await file.exists()) {
          _showExportSuccess(context);
        } else {
          setState(() {
            _errorMessage = 'Failed to create export file.';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error during export: $e';
      });
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  // Helper method to show success message
  void _showExportSuccess(BuildContext context) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Layout exported successfully to $_exportPath'),
          action: SnackBarAction(
            label: 'OPEN',
            onPressed: () {
              // Open the file or folder - platform specific
              if (Platform.isWindows) {
                Process.run('explorer.exe', ['/select,', _exportPath!]);
              } else if (Platform.isMacOS) {
                Process.run('open', ['-R', _exportPath!]);
              } else if (Platform.isLinux) {
                Process.run('xdg-open', [path.dirname(_exportPath!)]);
              }
            },
          ),
        ),
      );
    }
  }
}
