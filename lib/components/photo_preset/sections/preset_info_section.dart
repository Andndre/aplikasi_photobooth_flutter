import 'package:flutter/material.dart';
import 'package:photobooth/models/event_model.dart';
import 'package:photobooth/models/preset_model.dart';
import 'package:photobooth/providers/event_provider.dart';
import 'package:photobooth/providers/preset_provider.dart';
import 'package:provider/provider.dart';

class PresetInfoSection extends StatelessWidget {
  final PresetModel preset;
  final bool isEditing;
  final PresetProvider presetProvider;
  final Function(PresetModel) onPresetUpdated;
  final Function() pickSampleImage;
  final String? currentEventId; // Parameter for current event ID
  final Function(String) onSetAsActiveForEvent; // Required callback

  const PresetInfoSection({
    super.key,
    required this.preset,
    required this.isEditing,
    required this.presetProvider,
    required this.onPresetUpdated,
    required this.pickSampleImage,
    this.currentEventId,
    required this.onSetAsActiveForEvent, // Make this required
  });

  @override
  Widget build(BuildContext context) {
    // Get the current event from context if possible
    EventModel? currentEvent;
    if (currentEventId != null) {
      try {
        final eventsProvider = Provider.of<EventsProvider>(
          context,
          listen: false,
        );
        currentEvent = eventsProvider.getEventById(currentEventId!);
      } catch (e) {
        // Silently ignore if we can't get the event
      }
    }

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
              // Single button that both sets as active and applies to current event
              IconButton(
                icon: const Icon(Icons.check_circle),
                tooltip: 'Set as Active Preset',
                onPressed: () {
                  // Set as active in PresetProvider, passing current event if available
                  presetProvider.setActivePreset(
                    preset.id,
                    context: context,
                    currentEvent: currentEvent,
                  );

                  // Show feedback to user
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${preset.name} set as active preset${currentEvent != null ? ' for ${currentEvent.name}' : ''}',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );

                  // Also call the traditional callback if available
                  if (currentEvent != null) {
                    onSetAsActiveForEvent(preset.id);
                  }
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
