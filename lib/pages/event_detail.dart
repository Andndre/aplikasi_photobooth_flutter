import 'package:flutter/material.dart';
import '../models/event.dart';

class EventDetail extends StatelessWidget {
  final Event event;

  const EventDetail({required this.event, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(event.name)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Description: ${event.description}',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('Date: ${event.date}', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Text(
              'Layout ID: ${event.layoutId}',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Save Folder: ${event.saveFolder}',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Upload Folder: ${event.uploadFolder}',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
