import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:photobooth/models/preset_model.dart';
import 'package:path/path.dart' as path;

class ImageProcessor {
  // Process an image with a preset and return the modified image
  static Future<File?> processImage(File imageFile, PresetModel preset) async {
    try {
      // Read the image
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return null;

      // Create a copy to modify
      img.Image processedImage = img.copyResize(
        image,
        width: image.width,
        height: image.height,
      );

      // Apply image processing operations in the correct order:

      // 1. Black and White (if enabled)
      if (preset.blackAndWhite) {
        processedImage = img.grayscale(processedImage);
      }
      // 2. Otherwise apply saturation adjustment (only if not in B&W mode)
      else if (preset.saturation != 0) {
        processedImage = _adjustSaturation(processedImage, preset.saturation);
      }

      // 3. Adjust brightness (-1.0 to 1.0)
      if (preset.brightness != 0) {
        // Manual brightness adjustment since the package may have changed
        processedImage = _adjustBrightness(processedImage, preset.brightness);
      }

      // 4. Adjust contrast (-1.0 to 1.0)
      if (preset.contrast != 0) {
        // Convert to a value between 0.0 and 4.0 for the library (0.5 to 2.0 is a reasonable range)
        final contrastFactor =
            preset.contrast > 0
                ? 1.0 + preset.contrast
                : 1.0 / (1.0 - preset.contrast);

        try {
          // Try using the contrast method if available
          processedImage = img.contrast(
            processedImage,
            contrast: contrastFactor,
          );
        } catch (e) {
          // Fallback to manual contrast adjustment
          processedImage = _adjustContrast(processedImage, preset.contrast);
        }
      }

      // 5. Apply border if needed
      if (preset.borderWidth > 0) {
        final borderSize = preset.borderWidth.round();
        final color = img.ColorRgb8(
          preset.borderColor.red,
          preset.borderColor.green,
          preset.borderColor.blue,
        );

        // Create a new image with borders
        final borderedImage = img.Image(
          width: processedImage.width + borderSize * 2,
          height: processedImage.height + borderSize * 2,
        );

        // Fill with border color
        img.fill(borderedImage, color: color);

        // Paste original image in the center
        img.compositeImage(
          borderedImage,
          processedImage,
          dstX: borderSize,
          dstY: borderSize,
        );

        processedImage = borderedImage;
      }

      // Save the processed image to a temporary file
      final tempDir = await getTemporaryDirectory();
      final outputPath = path.join(
        tempDir.path,
        'processed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(
        Uint8List.fromList(img.encodeJpg(processedImage)),
      );

      return outputFile;
    } catch (e) {
      print('Error processing image: $e');
      return null;
    }
  }

  // Manual brightness adjustment implementation
  static img.Image _adjustBrightness(img.Image image, double brightness) {
    // Convert brightness from -1.0...1.0 to -255...255
    final amount = (brightness * 255).round();

    // Create a copy to modify
    final result = img.Image.from(image);

    // Apply brightness adjustment
    for (var y = 0; y < result.height; y++) {
      for (var x = 0; x < result.width; x++) {
        final pixel = result.getPixel(x, y);

        // Get color components
        int r = pixel.r.toInt();
        int g = pixel.g.toInt();
        int b = pixel.b.toInt();
        int a = pixel.a.toInt();

        // Adjust each channel
        r = math.max(0, math.min(255, r + amount));
        g = math.max(0, math.min(255, g + amount));
        b = math.max(0, math.min(255, b + amount));

        // Set the new pixel
        result.setPixel(x, y, img.ColorRgba8(r, g, b, a));
      }
    }

    return result;
  }

  // Manual contrast adjustment implementation
  static img.Image _adjustContrast(img.Image image, double contrastValue) {
    // Convert from -1.0...1.0 to 0.5...2.0 factor
    final factor =
        contrastValue > 0 ? 1.0 + contrastValue : 1.0 / (1.0 - contrastValue);

    // Create a copy to modify
    final result = img.Image.from(image);

    // Calculate average luminance as reference point for contrast
    double totalLuminance = 0;
    for (var y = 0; y < result.height; y++) {
      for (var x = 0; x < result.width; x++) {
        final pixel = result.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();

        // Use standard luminance formula
        totalLuminance += (0.299 * r + 0.587 * g + 0.114 * b);
      }
    }

    // Calculate average luminance
    final avgLuminance = totalLuminance / (result.width * result.height);

    // Apply contrast adjustment
    for (var y = 0; y < result.height; y++) {
      for (var x = 0; x < result.width; x++) {
        final pixel = result.getPixel(x, y);

        // Get color components
        int r = pixel.r.toInt();
        int g = pixel.g.toInt();
        int b = pixel.b.toInt();
        int a = pixel.a.toInt();

        // Adjust distance from average
        r = _adjustComponentContrast(r, avgLuminance.toInt(), factor);
        g = _adjustComponentContrast(g, avgLuminance.toInt(), factor);
        b = _adjustComponentContrast(b, avgLuminance.toInt(), factor);

        // Set the adjusted pixel
        result.setPixel(x, y, img.ColorRgba8(r, g, b, a));
      }
    }

    return result;
  }

  // Helper for contrast adjustment
  static int _adjustComponentContrast(int value, int midPoint, double factor) {
    final int adjusted = midPoint + ((value - midPoint) * factor).round();
    return math.max(0, math.min(255, adjusted));
  }

  // Manual implementation of saturation adjustment
  static img.Image _adjustSaturation(img.Image image, double saturationValue) {
    // Create a copy to modify
    img.Image result = img.Image.from(image);

    // Calculate saturation factor (0.0 - 2.0 range where 1.0 is normal)
    double factor = 1.0 + saturationValue; // -1.0 to 1.0 -> 0.0 to 2.0

    // Apply to each pixel
    for (int y = 0; y < result.height; y++) {
      for (int x = 0; x < result.width; x++) {
        final pixel = result.getPixel(x, y);

        // Extract color components
        int r = pixel.r.toInt();
        int g = pixel.g.toInt();
        int b = pixel.b.toInt();
        int a = pixel.a.toInt();

        // Convert RGB to HSL (Hue, Saturation, Lightness)
        final hsl = _rgbToHsl(r, g, b);
        final double h = hsl[0], s = hsl[1], l = hsl[2];

        // Adjust saturation
        final double newS = math.max(0, math.min(1, s * factor));

        // Convert back to RGB
        final adjusted = _hslToRgb(h, newS, l);

        // Update pixel
        result.setPixel(
          x,
          y,
          img.ColorRgba8(adjusted[0], adjusted[1], adjusted[2], a),
        );
      }
    }

    return result;
  }

  // Convert RGB to HSL (Hue, Saturation, Lightness)
  static List<double> _rgbToHsl(int r, int g, int b) {
    // Normalize RGB values
    double rf = r / 255;
    double gf = g / 255;
    double bf = b / 255;

    double max = math.max(math.max(rf, gf), bf);
    double min = math.min(math.min(rf, gf), bf);
    double h = 0, s = 0, l = (max + min) / 2;

    // Calculate saturation
    if (max == min) {
      s = 0; // achromatic
      h = 0; // achromatic
    } else {
      double d = max - min;
      s = l > 0.5 ? d / (2 - max - min) : d / (max + min);

      // Calculate hue
      if (max == rf) {
        h = (gf - bf) / d + (gf < bf ? 6 : 0);
      } else if (max == gf) {
        h = (bf - rf) / d + 2;
      } else {
        h = (rf - gf) / d + 4;
      }

      h /= 6;
    }

    return [h, s, l];
  }

  // Convert HSL to RGB
  static List<int> _hslToRgb(double h, double s, double l) {
    double r, g, b;

    if (s == 0) {
      // achromatic
      r = g = b = l;
    } else {
      double q = l < 0.5 ? l * (1 + s) : l + s - l * s;
      double p = 2 * l - q;
      r = _hue2rgb(p, q, h + 1 / 3);
      g = _hue2rgb(p, q, h);
      b = _hue2rgb(p, q, h - 1 / 3);
    }

    return [(r * 255).round(), (g * 255).round(), (b * 255).round()];
  }

  static double _hue2rgb(double p, double q, double t) {
    if (t < 0) t += 1;
    if (t > 1) t -= 1;
    if (t < 1 / 6) return p + (q - p) * 6 * t;
    if (t < 1 / 2) return q;
    if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
    return p;
  }

  // Generate a preview of the processed image for display
  static Future<Uint8List?> generatePreview(
    File imageFile,
    PresetModel preset,
  ) async {
    try {
      final processedFile = await processImage(imageFile, preset);
      if (processedFile != null) {
        return await processedFile.readAsBytes();
      }
      return null;
    } catch (e) {
      print('Error generating preview: $e');
      return null;
    }
  }

  // Load a built-in placeholder image as a File
  static Future<File> getPlaceholderImage() async {
    try {
      final byteData = await rootBundle.load(
        'assets/images/sample_placeholder.jpg',
      );
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/placeholder.jpg');
      await file.writeAsBytes(
        byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
      );
      return file;
    } catch (e) {
      print('Error loading placeholder image: $e');
      // Create a simple placeholder image
      return _createFallbackPlaceholder();
    }
  }

  // Create a simple placeholder image if the asset isn't found
  static Future<File> _createFallbackPlaceholder() async {
    // Create a simple placeholder image
    final image = img.Image(width: 640, height: 480);

    // Fill with gray
    img.fill(image, color: img.ColorRgb8(200, 200, 200));

    // Add some text - simplified approach without font
    final centerX = image.width ~/ 2;
    final centerY = image.height ~/ 2;

    // Draw a rectangle to represent a sample image
    for (var x = centerX - 100; x < centerX + 100; x++) {
      for (var y = centerY - 75; y < centerY + 75; y++) {
        if (x == centerX - 100 ||
            x == centerX + 99 ||
            y == centerY - 75 ||
            y == centerY + 74) {
          // Draw border
          image.setPixel(x, y, img.ColorRgb8(100, 100, 100));
        }
      }
    }

    // Save to temp file
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/fallback_placeholder.jpg');
    await file.writeAsBytes(Uint8List.fromList(img.encodeJpg(image)));
    return file;
  }
}
