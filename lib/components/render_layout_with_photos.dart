import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:screenshot/screenshot.dart';
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
  // Controller only needed for capturing if needed
  final ScreenshotController _screenshotController = ScreenshotController();

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
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Export Layout: ${widget.layout.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.image),
            tooltip: 'Export as Image',
            onPressed: _hasAnyPhotos() ? _exportLayout : null,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Export settings
            Card(
              margin: const EdgeInsets.only(bottom: 16.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Export Settings',
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Resolution selector
                    Text(
                      'Resolution Multiplier',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildResolutionButton(1.0, '1x'),
                        _buildResolutionButton(1.5, '1.5x'),
                        _buildResolutionButton(2.0, '2x'),
                        _buildResolutionButton(3.0, '3x'),
                        _buildResolutionButton(4.0, '4x'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Output size: ${(widget.layout.width * _resolutionMultiplier).round()} × ${(widget.layout.height * _resolutionMultiplier).round()} px',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 16),

                    // Include background option
                    CheckboxListTile(
                      title: const Text('Include Background'),
                      value: _includeBackground,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) {
                        setState(() {
                          _includeBackground = value ?? true;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Photo selection section
            Text(
              'Select Photos',
              style: Theme.of(
                context,
              ).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Text(
              'Select photos for each camera slot in your layout:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),

            const SizedBox(height: 16),

            // Camera slot list
            Expanded(
              child:
                  cameraElements.isEmpty
                      ? const Center(
                        child: Text('No camera slots found in this layout.'),
                      )
                      : ListView.builder(
                        itemCount: cameraElements.length,
                        itemBuilder: (context, index) {
                          final cameraElement = cameraElements[index];
                          final hasPhoto =
                              index < _photoFilePaths.length &&
                              _photoFilePaths[index].isNotEmpty;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8.0),
                            child: ListTile(
                              leading:
                                  hasPhoto
                                      ? _buildThumbnail(_photoFilePaths[index])
                                      : const Icon(Icons.camera_alt),
                              title: Text(cameraElement.id),
                              subtitle: Text(
                                hasPhoto
                                    ? path.basename(_photoFilePaths[index])
                                    : 'No photo selected',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.add_photo_alternate),
                                onPressed: () => _selectPhoto(index),
                              ),
                            ),
                          );
                        },
                      ),
            ),

            // Export button
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: ElevatedButton.icon(
                onPressed:
                    _hasAnyPhotos() && !_isExporting ? _exportLayout : null,
                icon:
                    _isExporting
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.download),
                label: Text(_isExporting ? 'Exporting...' : 'Export Layout'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Build a thumbnail preview of the selected photo
  Widget _buildThumbnail(String photoPath) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        image: DecorationImage(
          image: FileImage(File(photoPath)),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  // Create a resolution selection button
  Widget _buildResolutionButton(double value, String label) {
    final isSelected = _resolutionMultiplier == value;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: ElevatedButton(
          onPressed: () {
            setState(() {
              _resolutionMultiplier = value;
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerLow,
            foregroundColor:
                isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          ),
          child: Text(label),
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

      if (result != null &&
          result.files.isNotEmpty &&
          result.files.first.path != null) {
        setState(() {
          // Ensure list is large enough
          while (_photoFilePaths.length <= index) {
            _photoFilePaths.add('');
          }
          _photoFilePaths[index] = result.files.first.path!;
          _errorMessage = null; // Clear any previous error
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error selecting photo: $e';
      });
      print('Error selecting photo: $e');
    }
  }

  // Updated export method using the Layouts class directly
  Future<void> _exportLayout() async {
    // Choose export location
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Export Location',
    );

    if (selectedDirectory == null) return;

    // Generate default filename
    String defaultFilename =
        '${widget.layout.name.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.png';
    final exportPath = path.join(selectedDirectory, defaultFilename);

    setState(() {
      _exportPath = exportPath;
      _isExporting = true;
      _errorMessage = null;
    });

    try {
      // Use the Layouts.exportAsImage method directly
      final file = await widget.layout.exportAsImage(
        exportPath: exportPath,
        photoFilePaths: _photoFilePaths,
        resolutionMultiplier: _resolutionMultiplier,
        includeBackground: _includeBackground,
      );

      // Check if export was successful
      if (file != null && await file.exists()) {
        _showExportSuccess(context);
      } else {
        setState(() {
          _errorMessage = 'Export failed. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error during export: $e';
      });
      print('Export error: $e');
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
          content: Text('Layout exported successfully to:\n$_exportPath'),
          action: SnackBarAction(
            label: 'OPEN',
            onPressed: () {
              // Open file or folder with platform-specific method
              if (Platform.isWindows) {
                Process.run('explorer.exe', ['/select,', _exportPath!]);
              } else if (Platform.isMacOS) {
                Process.run('open', ['-R', _exportPath!]);
              } else if (Platform.isLinux) {
                Process.run('xdg-open', [path.dirname(_exportPath!)]);
              }
            },
          ),
          duration: const Duration(seconds: 6),
        ),
      );

      // Navigate back after successful export
      Navigator.of(context).pop();
    }
  }
}
