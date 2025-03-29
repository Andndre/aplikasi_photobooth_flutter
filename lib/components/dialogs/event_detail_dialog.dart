import 'package:flutter/material.dart';
import 'package:photobooth/components/common/dialog_header.dart';
import 'package:photobooth/components/common/dialog_buttons.dart';
import 'package:photobooth/models/event_model.dart';
import 'package:photobooth/providers/layout_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class EventDetailDialog extends StatelessWidget {
  final EventModel event;

  const EventDetailDialog({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('MMMM d, yyyy');
    final eventDate = DateTime.parse(event.date);
    final formattedDate = dateFormatter.format(eventDate);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.6,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DialogHeader(
              title: 'Event Details',
              onClose: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailSection(context, 'Name', event.name),
                    _buildDetailSection(
                      context,
                      'Description',
                      event.description,
                    ),
                    _buildDetailSection(context, 'Date', formattedDate),
                    Consumer<LayoutsProvider>(
                      builder: (context, layoutsProvider, child) {
                        final layout = layoutsProvider.getLayoutById(
                          event.layoutId,
                        );
                        return _buildDetailSection(
                          context,
                          'Layout',
                          layout != null ? layout.name : 'Layout not found',
                        );
                      },
                    ),
                    _buildDetailSection(
                      context,
                      'Save Folder',
                      event.saveFolder,
                    ),
                    _buildDetailSection(
                      context,
                      'Upload Folder',
                      event.uploadFolder,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            DialogButtons(
              cancelText: 'Close',
              onCancel: () => Navigator.of(context).pop(),
              showConfirm: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
