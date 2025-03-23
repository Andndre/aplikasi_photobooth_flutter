import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import '../models/layouts.dart';
import '../providers/layout_editor.dart';

class ExportDialog extends StatefulWidget {
  final Layouts layout;
  final LayoutEditorProvider editorProvider; // Add this parameter

  const ExportDialog({
    super.key,
    required this.layout,
    required this.editorProvider, // Required parameter
  });

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  double _resolutionMultiplier = 1.0;
  bool _isExporting = false;
  bool _includeBackground = true;
  bool _includeSamplePhotos = true;
  String? _exportPath;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    // Now we use widget.editorProvider instead of Provider.of
    final editorProvider = widget.editorProvider;

    // Calculate dimensions based on the resolution multiplier
    final width = (widget.layout.width * _resolutionMultiplier).round();
    final height = (widget.layout.height * _resolutionMultiplier).round();

    return AlertDialog(
      title: const Text('Export Layout as Image'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resolution multiplier selection
            _buildSectionHeader('Resolution'),

            const Text(
              'Choose the export resolution multiplier:',
              style: TextStyle(fontSize: 12),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  _buildResolutionButton(1.0, '1x'),
                  const SizedBox(width: 8),
                  _buildResolutionButton(1.5, '1.5x'),
                  const SizedBox(width: 8),
                  _buildResolutionButton(2.0, '2x'),
                  const SizedBox(width: 8),
                  _buildResolutionButton(3.0, '3x'),
                  const SizedBox(width: 8),
                  _buildResolutionButton(4.0, '4x'),
                ],
              ),
            ),

            Text(
              'Output size: $width × $height px',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),

            if (width > 8000 || height > 8000)
              const Padding(
                padding: EdgeInsets.only(top: 4.0),
                child: Text(
                  'Warning: Very large resolutions may take longer to process.',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),

            const SizedBox(height: 16),

            // Export options
            _buildSectionHeader('Options'),

            CheckboxListTile(
              dense: true,
              title: const Text('Include Background Color'),
              value: _includeBackground,
              onChanged: (value) {
                setState(() {
                  _includeBackground = value ?? true;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),

            CheckboxListTile(
              dense: true,
              title: const Text('Show Sample Photos in Camera Slots'),
              value: _includeSamplePhotos,
              onChanged: (value) {
                setState(() {
                  _includeSamplePhotos = value ?? true;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),

            const SizedBox(height: 16),

            // Export path selection
            _buildSectionHeader('Export Location'),

            Row(
              children: [
                Expanded(
                  child: Text(
                    _exportPath ?? 'No location selected',
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _isExporting ? null : _selectExportPath,
                  child: const Text('Choose Location'),
                ),
              ],
            ),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed:
              _isExporting || _exportPath == null
                  ? null
                  : () => _exportLayout(context, editorProvider),
          child:
              _isExporting
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('Export'),
        ),
      ],
    );
  }

  Widget _buildResolutionButton(double value, String label) {
    final isSelected = _resolutionMultiplier == value;

    return Expanded(
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _resolutionMultiplier = value;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerLowest,
          foregroundColor:
              isSelected
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onSurfaceVariant,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const Divider(),
        ],
      ),
    );
  }

  Future<void> _selectExportPath() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose Export Location',
    );

    if (selectedDirectory != null) {
      // Generate a default filename based on the layout name and timestamp
      String defaultFilename =
          '${widget.layout.name.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.png';

      setState(() {
        _exportPath = path.join(selectedDirectory, defaultFilename);
        _errorMessage = null;
      });
    }
  }

  Future<void> _exportLayout(
    BuildContext context,
    LayoutEditorProvider provider,
  ) async {
    if (_exportPath == null) {
      setState(() {
        _errorMessage = 'Please select an export location first.';
      });
      return;
    }

    setState(() {
      _isExporting = true;
      _errorMessage = null;
    });

    try {
      // Export the layout using the provider's method
      final file = await provider.exportLayoutAsImage(
        exportPath: _exportPath!,
        resolutionMultiplier: _resolutionMultiplier,
        includeBackground: _includeBackground,
        includeSamplePhotos: _includeSamplePhotos,
      );

      // Check if the file was successfully created
      if (file != null && await file.exists()) {
        // Close the dialog and show a success message
        if (context.mounted) {
          Navigator.of(context).pop();

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
      } else {
        setState(() {
          _errorMessage = 'Failed to create the export file.';
          _isExporting = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error during export: ${e.toString()}';
        _isExporting = false;
      });
    }
  }
}
