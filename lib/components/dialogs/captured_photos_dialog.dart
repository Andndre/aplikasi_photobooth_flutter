import 'dart:io';
import 'package:flutter/material.dart';

class CapturedPhotosDialog extends StatelessWidget {
  final List<File> photos;
  final Function(int) onRetake;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const CapturedPhotosDialog({
    super.key,
    required this.photos,
    required this.onRetake,
    required this.onConfirm,
    required this.onCancel,
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
                onPressed: onCancel,
                child: const Text('Cancel'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
              TextButton(
                onPressed: onConfirm,
                child: const Text('Confirm & Generate'),
              ),
            ],
          ),
          Flexible(
            child: GridView.builder(
              padding: const EdgeInsets.all(12.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10.0,
                mainAxisSpacing: 10.0,
                childAspectRatio: 1.0, // Square grid cells
              ),
              shrinkWrap: true,
              itemCount: photos.length,
              itemBuilder: (context, index) {
                return Card(
                  clipBehavior: Clip.antiAlias,
                  elevation: 3.0,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Use AspectRatio to maintain image aspect ratio
                      AspectRatio(
                        aspectRatio: 1.0,
                        child: Image.file(
                          photos[index],
                          fit:
                              BoxFit
                                  .cover, // Cover the space while maintaining aspect ratio
                        ),
                      ),
                      // Add a small badge with photo number
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4.0),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      // Retake button as overlay
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => onRetake(index),
                            child: Container(
                              padding: const EdgeInsets.all(6.0),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.refresh,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
