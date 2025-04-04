import 'package:flutter/material.dart';
import 'package:photobooth/models/preset_model.dart';
import 'package:photobooth/providers/preset_provider.dart';

class ActionButtonsSection extends StatelessWidget {
  final PresetModel preset;
  final bool isEditing;
  final PresetProvider presetProvider;
  final Function() onCancel;
  final String? eventId;

  const ActionButtonsSection({
    super.key,
    required this.preset,
    required this.isEditing,
    required this.presetProvider,
    required this.onCancel,
    this.eventId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),

        // Save/Cancel buttons when editing
        if (isEditing)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(onPressed: onCancel, child: const Text('Cancel')),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  final updatedPreset = preset;
                  presetProvider.updatePreset(updatedPreset);
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

        if (eventId != null && !isEditing)
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
    );
  }
}
