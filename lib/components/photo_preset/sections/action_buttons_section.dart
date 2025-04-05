import 'package:flutter/material.dart';
import 'package:photobooth/models/preset_model.dart';
import 'package:photobooth/providers/preset_provider.dart';
import 'package:photobooth/providers/event_provider.dart'; // Add event provider import
import 'package:provider/provider.dart'; // Add provider import

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
        const Divider(),
        const SizedBox(height: 8),

        // Different buttons based on edit mode
        if (isEditing)
          // Edit mode buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    presetProvider.savePreset(preset);

                    // If there's an event ID, update its preset
                    if (eventId != null) {
                      _updateEventPreset(context, eventId!, preset.id);
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          eventId != null
                              ? 'Preset saved and applied to event'
                              : 'Preset saved',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          )
        else if (eventId != null)
          // View mode with event ID - show informational message and apply button
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Apply this preset to event "$eventId"',
                        style: TextStyle(
                          color: Colors.green[800],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Set as active preset
                    presetProvider.setActivePreset(preset.id);

                    // Update the event preset
                    _updateEventPreset(context, eventId!, preset.id);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${preset.name} set as active and applied to event',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Apply to Event'),
                ),
              ),
            ],
          )
        else
          // Regular view mode button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                presetProvider.setActivePreset(preset.id);

                // Also update the current event's presetId if we're in an event context
                // Get current event ID first before updating
                final currentEventId = _getCurrentEventId(context);
                if (currentEventId != null) {
                  _updateEventPreset(context, currentEventId, preset.id);
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      currentEventId != null
                          ? '${preset.name} set as active and applied to event'
                          : '${preset.name} set as active preset',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.check_circle),
              label: const Text('Set as Active Preset'),
            ),
          ),
      ],
    );
  }

  // Helper method to update an event's preset
  void _updateEventPreset(
    BuildContext context,
    String eventName,
    String presetId,
  ) {
    try {
      // Get the EventsProvider
      final eventsProvider = Provider.of<EventsProvider>(
        context,
        listen: false,
      );

      // Find the event by name
      final event = eventsProvider.getEventByName(eventName);

      if (event != null) {
        // Update the event's presetId
        event.updatePresetId(presetId);
        print('Updated event "${event.name}" with preset ID: $presetId');

        // Save events to persist changes using a public method
        eventsProvider.saveEvents();
      } else {
        print('Event not found: $eventName');
      }
    } catch (e) {
      print('Error updating event preset: $e');
    }
  }

  // Helper to try getting current event ID from context if available
  String? _getCurrentEventId(BuildContext context) {
    // Try to access from route arguments if this was opened from an event page
    try {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic> && args.containsKey('eventId')) {
        return args['eventId'] as String;
      }
    } catch (e) {
      print('Error getting route arguments: $e');
    }

    return null; // No current event ID found
  }
}
