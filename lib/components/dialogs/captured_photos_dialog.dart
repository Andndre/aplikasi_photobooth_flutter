import 'dart:io';
import 'package:flutter/material.dart';

class CapturedPhotosDialog extends StatelessWidget {
  final List<File> photos;
  final Function(int) onRetake;
  final VoidCallback onConfirm;

  const CapturedPhotosDialog({
    super.key,
    required this.photos,
    required this.onRetake,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBar(
            title: const Text('Captured Photos'),
            actions: [
              TextButton(
                onPressed: onConfirm,
                child: const Text('Confirm & Generate'),
              ),
            ],
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: photos.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: SizedBox(
                    width: 60,
                    height: 60,
                    child: Image.file(photos[index], fit: BoxFit.cover),
                  ),
                  title: Text('Photo ${index + 1}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      // Just call onRetake callback without trying to navigate
                      onRetake(index);
                      // Dialog will be closed by the callback
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
