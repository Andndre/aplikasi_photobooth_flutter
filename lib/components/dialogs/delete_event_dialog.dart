import 'package:flutter/material.dart';
import 'package:photobooth/components/common/dialog_buttons.dart';
import 'package:photobooth/components/common/dialog_header.dart';
import 'package:photobooth/models/event_model.dart';
import 'package:photobooth/providers/event_provider.dart';
import 'package:provider/provider.dart';

class DeleteEventDialog extends StatelessWidget {
  final EventModel event;
  final int index;

  const DeleteEventDialog({
    super.key,
    required this.event,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DialogHeader(
              title: 'Delete Event',
              onClose: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 16),
            Text(
              'Are you sure you want to delete this event?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Event: ${event.name}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 24),
            DialogButtons(
              cancelText: 'Cancel',
              confirmText: 'Delete',
              confirmColor: Theme.of(context).colorScheme.error,
              onCancel: () => Navigator.of(context).pop(),
              onConfirm: () {
                Provider.of<EventsProvider>(
                  context,
                  listen: false,
                ).removeEvent(index);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
