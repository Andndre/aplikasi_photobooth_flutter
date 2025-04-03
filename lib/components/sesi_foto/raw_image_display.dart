import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';

// Widget to efficiently display raw image data without PNG conversion
class RawImageDisplay extends StatefulWidget {
  final Uint8List imageBytes;
  final int width;
  final int height;

  const RawImageDisplay({
    super.key,
    required this.imageBytes,
    required this.width,
    required this.height,
  });

  @override
  RawImageDisplayState createState() => RawImageDisplayState();
}

class RawImageDisplayState extends State<RawImageDisplay> {
  ui.Image? _image;
  ui.Image? _previousImage;
  bool _isConverting = false;
  late final Paint _imagePaint;

  @override
  void initState() {
    super.initState();
    // Configure image paint for better performance - use lowest quality
    _imagePaint =
        Paint()
          ..filterQuality = FilterQuality.none
          ..isAntiAlias = false;
    _convertToImage();
  }

  @override
  void didUpdateWidget(RawImageDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Optimize by checking if pixels have actually changed
    final bytesChanged = widget.imageBytes != oldWidget.imageBytes;
    final sizeChanged =
        widget.width != oldWidget.width || widget.height != oldWidget.height;

    if (sizeChanged || bytesChanged) {
      _convertToImage();
    }
  }

  Future<void> _convertToImage() async {
    if (_isConverting) return;

    _isConverting = true;

    try {
      // Use the highest performance method available for image conversion
      final completer = Completer<ui.Image>();

      ui.decodeImageFromPixels(
        widget.imageBytes,
        widget.width,
        widget.height,
        ui.PixelFormat.rgba8888,
        (ui.Image result) {
          completer.complete(result);
        },
        // Don't scale during decode, as we'll do that during painting
        // for better performance
        rowBytes: widget.width * 4,
      );

      final image = await completer.future;

      if (mounted) {
        setState(() {
          _previousImage = _image;
          _image = image;
        });
      }
    } catch (e) {
      // Add this error log as it's important for debugging
      print('Error converting image: $e');
    } finally {
      _isConverting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use RepaintBoundary to optimize rendering performance
    return RepaintBoundary(
      child:
          _image != null
              ? CustomPaint(
                painter: RawImagePainter(
                  image: _image!,
                  thisPaint: _imagePaint,
                ),
                size: Size(widget.width.toDouble(), widget.height.toDouble()),
              )
              : _previousImage != null
              ? CustomPaint(
                painter: RawImagePainter(
                  image: _previousImage!,
                  thisPaint: _imagePaint,
                ),
                size: Size(widget.width.toDouble(), widget.height.toDouble()),
              )
              : Container(color: Colors.black),
    );
  }
}

// Custom painter to efficiently render the ui.Image
class RawImagePainter extends CustomPainter {
  final ui.Image image;
  final Paint thisPaint;

  RawImagePainter({required this.image, required this.thisPaint});

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate optimal scaling
    final double scaleX = size.width / image.width;
    final double scaleY = size.height / image.height;
    final double scale = math.min(scaleX, scaleY);

    // Calculate centered position
    final double left = (size.width - (image.width * scale)) / 2;
    final double top = (size.height - (image.height * scale)) / 2;

    final Rect rect = Rect.fromLTWH(
      left,
      top,
      image.width * scale,
      image.height * scale,
    );

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      rect,
      thisPaint,
    );
  }

  @override
  bool shouldRepaint(RawImagePainter oldDelegate) {
    // Only repaint if the image reference has changed
    return oldDelegate.image != image;
  }
}
