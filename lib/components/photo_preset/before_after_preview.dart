import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class BeforeAfterPreview extends StatefulWidget {
  final File? currentSampleImage;
  final Uint8List? processedImagePreview;

  const BeforeAfterPreview({
    super.key,
    required this.currentSampleImage,
    required this.processedImagePreview,
  });

  @override
  State<BeforeAfterPreview> createState() => _BeforeAfterPreviewState();
}

class _BeforeAfterPreviewState extends State<BeforeAfterPreview> {
  // Zoom levels for both images
  double _beforeZoom = 1.0;
  double _afterZoom = 1.0;

  // Scroll controllers to handle scrolling in both directions
  final ScrollController _beforeHorizontalScrollController = ScrollController();
  final ScrollController _beforeVerticalScrollController = ScrollController();
  final ScrollController _afterHorizontalScrollController = ScrollController();
  final ScrollController _afterVerticalScrollController = ScrollController();

  @override
  void dispose() {
    _beforeHorizontalScrollController.dispose();
    _beforeVerticalScrollController.dispose();
    _afterHorizontalScrollController.dispose();
    _afterVerticalScrollController.dispose();
    super.dispose();
  }

  // Adjust zoom level with bounds
  void _adjustZoom(bool isBeforeImage, double delta) {
    setState(() {
      if (isBeforeImage) {
        _beforeZoom = (_beforeZoom + delta).clamp(1.0, 5.0);
      } else {
        _afterZoom = (_afterZoom + delta).clamp(1.0, 5.0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate the height for each image container
        // giving each an equal share of the available height
        final containerHeight = constraints.maxHeight / 2 - 8;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Before image (original) - Top
            _buildImageContainer(
              true,
              widget.currentSampleImage != null
                  ? Image.file(widget.currentSampleImage!, fit: BoxFit.contain)
                  : const Center(child: Text('No image selected')),
              _beforeZoom,
              _beforeHorizontalScrollController,
              _beforeVerticalScrollController,
              constraints.maxWidth,
              containerHeight,
            ),

            const SizedBox(height: 16),

            // After image (processed) - Bottom
            _buildImageContainer(
              false,
              widget.processedImagePreview != null
                  ? Image.memory(
                    widget.processedImagePreview!,
                    fit: BoxFit.contain,
                  )
                  : widget.currentSampleImage != null
                  ? Image.file(
                    widget.currentSampleImage!,
                    fit: BoxFit.contain,
                    color: Colors.black.withOpacity(0.5),
                    colorBlendMode: BlendMode.darken,
                  )
                  : const Center(child: Text('No image selected')),
              _afterZoom,
              _afterHorizontalScrollController,
              _afterVerticalScrollController,
              constraints.maxWidth,
              containerHeight,
            ),
          ],
        );
      },
    );
  }

  // Build a container for an image with zoom controls and scrollbars
  Widget _buildImageContainer(
    bool isBeforeImage,
    Widget imageWidget,
    double zoomLevel,
    ScrollController horizontalController,
    ScrollController verticalController,
    double containerWidth,
    double containerHeight,
  ) {
    return Container(
      width: containerWidth,
      height: containerHeight,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Scrollable image with zoom
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Scrollbar(
              controller: horizontalController,
              thumbVisibility: zoomLevel > 1.0,
              child: Scrollbar(
                controller: verticalController,
                thumbVisibility: zoomLevel > 1.0,
                notificationPredicate:
                    (notification) => notification.depth == 1,
                child: SingleChildScrollView(
                  controller: horizontalController,
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    controller: verticalController,
                    child: SizedBox(
                      width:
                          containerWidth *
                          zoomLevel, // Scale width based on zoom
                      height:
                          containerHeight *
                          zoomLevel, // Scale height based on zoom
                      child: FittedBox(
                        alignment: Alignment.topLeft,
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: containerWidth,
                          height: containerHeight,
                          child: imageWidget,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Processing indicator (for after image)
          if (!isBeforeImage &&
              widget.processedImagePreview == null &&
              widget.currentSampleImage != null)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text('Processing...'),
                ],
              ),
            ),

          // Zoom controls
          Positioned(
            bottom: 8,
            right: 8,
            child: Row(
              children: [
                // Zoom out button
                Material(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _adjustZoom(isBeforeImage, -0.5),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      child: const Icon(
                        Icons.remove,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Zoom text indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(zoomLevel * 100).round()}%',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                // Zoom in button
                Material(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _adjustZoom(isBeforeImage, 0.5),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
