import 'package:flutter/material.dart';
import 'package:photobooth/models/preset_model.dart';
import 'package:photobooth/providers/preset_provider.dart';

class PresetInfoSection extends StatelessWidget {
  final PresetModel preset;
  final bool isEditing;
  final PresetProvider presetProvider;
  final Function(PresetModel) onPresetUpdated;
  final Function() pickSampleImage;

  const PresetInfoSection({
    super.key,
    required this.preset,
    required this.isEditing,
    required this.presetProvider,
    required this.onPresetUpdated,
    required this.pickSampleImage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title and action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                isEditing ? 'Edit Preset' : preset.name,
                style: Theme.of(context).textTheme.titleLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!isEditing)
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

        if (isEditing)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: pickSampleImage,
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('Change Sample Image'),
                  ),
                ),
              ],
            ),
          ),

        // Preset name edit field in edit mode
        if (isEditing) ...[
          TextFormField(
            initialValue: preset.name,
            decoration: const InputDecoration(
              labelText: 'Preset Name',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              onPresetUpdated(preset.copyWith(name: value));
            },
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
