import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:typed_data';

class BeforeAfterPreview extends StatefulWidget {
  final File? currentSampleImage;
  final Uint8List? processedImagePreview;

  const BeforeAfterPreview({
    super.key,
    this.currentSampleImage,
    this.processedImagePreview,
  });

  @override
  State<BeforeAfterPreview> createState() => _BeforeAfterPreviewState();
}

class _BeforeAfterPreviewState extends State<BeforeAfterPreview> {
  // Using separate zoom levels for each image
  double _beforeZoomLevel = 1.0;
  double _afterZoomLevel = 1.0;
  final double _minZoom = 0.5;
  final double _maxZoom = 3.0;
  final double _zoomStep = 0.25;

  // Controllers for scrollable views
  final TransformationController _beforeTransformController =
      TransformationController();
  final TransformationController _afterTransformController =
      TransformationController();

  final ScrollController _beforeHorizontalController = ScrollController();
  final ScrollController _beforeVerticalController = ScrollController();
  final ScrollController _afterHorizontalController = ScrollController();
  final ScrollController _afterVerticalController = ScrollController();

  @override
  void dispose() {
    _beforeTransformController.dispose();
    _afterTransformController.dispose();
    _beforeHorizontalController.dispose();
    _beforeVerticalController.dispose();
    _afterHorizontalController.dispose();
    _afterVerticalController.dispose();
    super.dispose();
  }

  void _zoomInBefore() {
    setState(() {
      _beforeZoomLevel = (_beforeZoomLevel + _zoomStep).clamp(
        _minZoom,
        _maxZoom,
      );
      _beforeTransformController.value =
          Matrix4.identity()..scale(_beforeZoomLevel);
    });
  }

  void _zoomOutBefore() {
    setState(() {
      _beforeZoomLevel = (_beforeZoomLevel - _zoomStep).clamp(
        _minZoom,
        _maxZoom,
      );
      _beforeTransformController.value =
          Matrix4.identity()..scale(_beforeZoomLevel);
    });
  }

  void _resetZoomBefore() {
    setState(() {
      _beforeZoomLevel = 1.0;
      _beforeTransformController.value = Matrix4.identity();
    });
  }

  void _zoomInAfter() {
    setState(() {
      _afterZoomLevel = (_afterZoomLevel + _zoomStep).clamp(_minZoom, _maxZoom);
      _afterTransformController.value =
          Matrix4.identity()..scale(_afterZoomLevel);
    });
  }

  void _zoomOutAfter() {
    setState(() {
      _afterZoomLevel = (_afterZoomLevel - _zoomStep).clamp(_minZoom, _maxZoom);
      _afterTransformController.value =
          Matrix4.identity()..scale(_afterZoomLevel);
    });
  }

  void _resetZoomAfter() {
    setState(() {
      _afterZoomLevel = 1.0;
      _afterTransformController.value = Matrix4.identity();
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.currentSampleImage == null
        ? const Center(child: Text('Select a preset to view preview'))
        : Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Preview (HD Resolution)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Text(
                    'Images are automatically resized for performance',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Before image (top)
                    Expanded(
                      child: Card(
                        elevation: 4,
                        child: Stack(
                          children: [
                            // Scrollable image view with both scrollbars
                            Positioned.fill(
                              child: Scrollbar(
                                controller: _beforeVerticalController,
                                thumbVisibility: true,
                                child: Scrollbar(
                                  controller: _beforeHorizontalController,
                                  thumbVisibility: true,
                                  notificationPredicate:
                                      (notification) => notification.depth == 1,
                                  child: InteractiveViewer(
                                    boundaryMargin: const EdgeInsets.all(20),
                                    minScale: _minZoom,
                                    maxScale: _maxZoom,
                                    transformationController:
                                        _beforeTransformController,
                                    onInteractionEnd: (details) {
                                      setState(() {
                                        _beforeZoomLevel =
                                            _beforeTransformController.value
                                                .getMaxScaleOnAxis();
                                      });
                                    },
                                    child: Center(
                                      child: Image.file(
                                        widget.currentSampleImage!,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Zoom controls in bottom right corner
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: Card(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surface.withOpacity(0.8),
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.zoom_in,
                                          size: 18,
                                        ),
                                        onPressed:
                                            _beforeZoomLevel < _maxZoom
                                                ? _zoomInBefore
                                                : null,
                                        tooltip: 'Zoom In',
                                        constraints: const BoxConstraints(
                                          minHeight: 32,
                                        ),
                                        padding: const EdgeInsets.all(4.0),
                                      ),
                                      Text(
                                        '${(_beforeZoomLevel * 100).round()}%',
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.zoom_out,
                                          size: 18,
                                        ),
                                        onPressed:
                                            _beforeZoomLevel > _minZoom
                                                ? _zoomOutBefore
                                                : null,
                                        tooltip: 'Zoom Out',
                                        constraints: const BoxConstraints(
                                          minHeight: 32,
                                        ),
                                        padding: const EdgeInsets.all(4.0),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.refresh,
                                          size: 18,
                                        ),
                                        onPressed:
                                            _beforeZoomLevel != 1.0
                                                ? _resetZoomBefore
                                                : null,
                                        tooltip: 'Reset Zoom',
                                        constraints: const BoxConstraints(
                                          minHeight: 32,
                                        ),
                                        padding: const EdgeInsets.all(4.0),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // After image (bottom)
                    Expanded(
                      child: Card(
                        elevation: 4,
                        child: Stack(
                          children: [
                            // Scrollable image view with both scrollbars
                            Positioned.fill(
                              child: Scrollbar(
                                controller: _afterVerticalController,
                                thumbVisibility: true,
                                child: Scrollbar(
                                  controller: _afterHorizontalController,
                                  thumbVisibility: true,
                                  notificationPredicate:
                                      (notification) => notification.depth == 1,
                                  child: InteractiveViewer(
                                    boundaryMargin: const EdgeInsets.all(20),
                                    minScale: _minZoom,
                                    maxScale: _maxZoom,
                                    transformationController:
                                        _afterTransformController,
                                    onInteractionEnd: (details) {
                                      setState(() {
                                        _afterZoomLevel =
                                            _afterTransformController.value
                                                .getMaxScaleOnAxis();
                                      });
                                    },
                                    child: Center(
                                      child:
                                          widget.processedImagePreview != null
                                              ? Image.memory(
                                                widget.processedImagePreview!,
                                                fit: BoxFit.contain,
                                              )
                                              : const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Zoom controls in bottom right corner
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: Card(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surface.withOpacity(0.8),
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.zoom_in,
                                          size: 18,
                                        ),
                                        onPressed:
                                            _afterZoomLevel < _maxZoom
                                                ? _zoomInAfter
                                                : null,
                                        tooltip: 'Zoom In',
                                        constraints: const BoxConstraints(
                                          minHeight: 32,
                                        ),
                                        padding: const EdgeInsets.all(4.0),
                                      ),
                                      Text(
                                        '${(_afterZoomLevel * 100).round()}%',
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.zoom_out,
                                          size: 18,
                                        ),
                                        onPressed:
                                            _afterZoomLevel > _minZoom
                                                ? _zoomOutAfter
                                                : null,
                                        tooltip: 'Zoom Out',
                                        constraints: const BoxConstraints(
                                          minHeight: 32,
                                        ),
                                        padding: const EdgeInsets.all(4.0),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.refresh,
                                          size: 18,
                                        ),
                                        onPressed:
                                            _afterZoomLevel != 1.0
                                                ? _resetZoomAfter
                                                : null,
                                        tooltip: 'Reset Zoom',
                                        constraints: const BoxConstraints(
                                          minHeight: 32,
                                        ),
                                        padding: const EdgeInsets.all(4.0),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
  }
}
