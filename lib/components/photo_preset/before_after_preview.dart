import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class BeforeAfterPreview extends StatelessWidget {
  final File? currentSampleImage;
  final Uint8List? processedImagePreview;

  const BeforeAfterPreview({
    super.key,
    required this.currentSampleImage,
    required this.processedImagePreview,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              // Original image (top)
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child:
                      currentSampleImage != null
                          ? Image.file(currentSampleImage!, fit: BoxFit.contain)
                          : const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              size: 50,
                              color: Colors.grey,
                            ),
                          ),
                ),
              ),

              const SizedBox(height: 16),

              // Processed image (bottom)
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child:
                      processedImagePreview != null
                          ? Image.memory(
                            processedImagePreview!,
                            fit: BoxFit.contain,
                          )
                          : currentSampleImage != null
                          ? Image.file(
                            currentSampleImage!,
                            fit: BoxFit.contain,
                            color: Colors.grey.withOpacity(0.5),
                            colorBlendMode: BlendMode.saturation,
                          )
                          : const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              size: 50,
                              color: Colors.grey,
                            ),
                          ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
