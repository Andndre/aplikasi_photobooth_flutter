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

      // 1. Apply temperature and tint (white balance)
      if (preset.temperature != 0.0 || preset.tint != 0.0) {
        processedImage = _adjustWhiteBalance(
          processedImage,
          preset.temperature,
          preset.tint,
        );
      }

      // 2. Apply exposure
      if (preset.exposure != 0.0) {
        processedImage = _adjustExposure(processedImage, preset.exposure);
      }

      // 3. Apply blacks and whites
      if (preset.blacks != 0.0 || preset.whites != 0.0) {
        processedImage = _adjustBlacksWhites(
          processedImage,
          preset.blacks,
          preset.whites,
        );
      }

      // 4. Apply highlights and shadows
      if (preset.highlights != 0.0 || preset.shadows != 0.0) {
        processedImage = _adjustHighlightsShadows(
          processedImage,
          preset.highlights,
          preset.shadows,
        );
      }

      // 5. Black and White (if enabled)
      if (preset.blackAndWhite) {
        processedImage = img.grayscale(processedImage);
      }
      // Otherwise apply saturation adjustment (only if not in B&W mode)
      else if (preset.saturation != 0) {
        processedImage = _adjustSaturation(processedImage, preset.saturation);
      }

      // 6. Adjust brightness (-1.0 to 1.0)
      if (preset.brightness != 0) {
        processedImage = _adjustBrightness(processedImage, preset.brightness);
      }

      // 7. Adjust contrast (-1.0 to 1.0)
      if (preset.contrast != 0) {
        final contrastFactor =
            preset.contrast > 0
                ? 1.0 + preset.contrast
                : 1.0 / (1.0 - preset.contrast);

        try {
          processedImage = img.contrast(
            processedImage,
            contrast: contrastFactor,
          );
        } catch (e) {
          processedImage = _adjustContrast(processedImage, preset.contrast);
        }
      }

      // 8. Apply border if needed
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

  // Adjust white balance (temperature and tint)
  static img.Image _adjustWhiteBalance(
    img.Image image,
    double temperature,
    double tint,
  ) {
    // Create a copy to modify
    final result = img.Image.from(image);

    // Temperature adjustment approach: instead of adding directly to color channels,
    // we'll use a more balanced approach based on color theory
    // For cooler tones (negative temperature), boost blues subtly and reduce reds/yellows
    // For warmer tones (positive temperature), boost reds/yellows subtly and reduce blues

    // Scale the temperature to a reasonable strength (avoid harsh blue overlay)
    final tempStrength =
        (temperature * 20).abs(); // Reduced from 30 to 20 for subtlety

    // Apply to each pixel
    for (var y = 0; y < result.height; y++) {
      for (var x = 0; x < result.width; x++) {
        final pixel = result.getPixel(x, y);

        // Get color components
        int r = pixel.r.toInt();
        int g = pixel.g.toInt();
        int b = pixel.b.toInt();
        int a = pixel.a.toInt();

        // Apply temperature: shift color balance
        if (temperature < 0) {
          // Cooler/blue
          // Instead of direct blue boost, use a multiplier approach for natural look
          double coolFactor =
              1.0 + (tempStrength.abs() / 100); // Subtle percentage boost

          // Enhance blue relative to its current value (multiplication instead of addition)
          b = math.min(255, (b * coolFactor).round());

          // For cooler temperatures, reduce red and yellow (yellow = red + green)
          r = math.max(0, (r * (1.0 - tempStrength.abs() / 200)).round());
          g = math.max(
            0,
            (g * (1.0 - tempStrength.abs() / 400)).round(),
          ); // Less reduction for green
        } else if (temperature > 0) {
          // Warmer/yellow
          // Warm up the image (boost red and green, which makes yellow)
          double warmFactor = 1.0 + (tempStrength / 100);

          // Enhance red and green for a warm yellow/orange look
          r = math.min(255, (r * warmFactor).round());
          g = math.min(
            255,
            (g * (1.0 + tempStrength / 200)).round(),
          ); // Slightly less boost for green

          // Reduce blue for warmer appearance
          b = math.max(0, (b * (1.0 - tempStrength / 200)).round());
        }

        // Apply tint: shift green-magenta balance
        if (tint < 0) {
          // More green
          // Enhance greens, reduce magenta (red and blue)
          double greenFactor = 1.0 + (tint.abs() * 0.2);
          g = math.min(255, (g * greenFactor).round());
          r = math.max(0, (r * (1.0 - tint.abs() * 0.1)).round());
          b = math.max(0, (b * (1.0 - tint.abs() * 0.1)).round());
        } else if (tint > 0) {
          // More magenta
          // Enhance red and blue (magenta), reduce green
          double magentaFactor = 1.0 + (tint * 0.2);
          r = math.min(255, (r * magentaFactor).round());
          b = math.min(255, (b * magentaFactor).round());
          g = math.max(0, (g * (1.0 - tint * 0.2)).round());
        }

        // Set the adjusted pixel
        result.setPixel(x, y, img.ColorRgba8(r, g, b, a));
      }
    }

    return result;
  }

  // Adjust exposure
  static img.Image _adjustExposure(img.Image image, double exposure) {
    // Create a copy to modify
    final result = img.Image.from(image);

    // Convert exposure to a factor (negative = darker, positive = brighter)
    final factor = math.pow(2, exposure).toDouble();

    // Apply to each pixel
    for (var y = 0; y < result.height; y++) {
      for (var x = 0; x < result.width; x++) {
        final pixel = result.getPixel(x, y);

        // Get color components
        int r = pixel.r.toInt();
        int g = pixel.g.toInt();
        int b = pixel.b.toInt();
        int a = pixel.a.toInt();

        // Apply exposure factor
        r = (r * factor).round().clamp(0, 255);
        g = (g * factor).round().clamp(0, 255);
        b = (b * factor).round().clamp(0, 255);

        // Set the adjusted pixel
        result.setPixel(x, y, img.ColorRgba8(r, g, b, a));
      }
    }

    return result;
  }

  // Adjust blacks and whites
  static img.Image _adjustBlacksWhites(
    img.Image image,
    double blacks,
    double whites,
  ) {
    // Create a copy to modify
    final result = img.Image.from(image);

    // Compute black and white points adjustment
    final blackPoint = (blacks * 50).round(); // Max 50 points shift
    final whitePoint =
        (whites * -50).round(); // Max 50 points shift (note: inverted)

    // Apply to each pixel
    for (var y = 0; y < result.height; y++) {
      for (var x = 0; x < result.width; x++) {
        final pixel = result.getPixel(x, y);

        // Get color components
        int r = pixel.r.toInt();
        int g = pixel.g.toInt();
        int b = pixel.b.toInt();
        int a = pixel.a.toInt();

        // Apply blacks adjustment
        if (blacks != 0) {
          r = (r > blackPoint) ? r : 0;
          g = (g > blackPoint) ? g : 0;
          b = (b > blackPoint) ? b : 0;
        }

        // Apply whites adjustment
        if (whites != 0) {
          r = (r < 255 - whitePoint) ? r : 255;
          g = (g < 255 - whitePoint) ? g : 255;
          b = (b < 255 - whitePoint) ? b : 255;
        }

        // Set the adjusted pixel
        result.setPixel(x, y, img.ColorRgba8(r, g, b, a));
      }
    }

    return result;
  }

  // Adjust highlights and shadows
  static img.Image _adjustHighlightsShadows(
    img.Image image,
    double highlights,
    double shadows,
  ) {
    // Create a copy to modify
    final result = img.Image.from(image);

    // Convert adjustments to factors
    // Fix: Invert the highlights factor so negative values increase highlights
    // and positive values reduce highlights (match Lightroom behavior)
    final highlightsFactor =
        1.0 + highlights; // Positive means darker highlights
    final shadowsFactor = 1.0 + shadows; // Positive means brighter shadows

    // Apply to each pixel
    for (var y = 0; y < result.height; y++) {
      for (var x = 0; x < result.width; x++) {
        final pixel = result.getPixel(x, y);

        // Get color components
        int r = pixel.r.toInt();
        int g = pixel.g.toInt();
        int b = pixel.b.toInt();
        int a = pixel.a.toInt();

        // Calculate luminance to determine if pixel is highlight or shadow
        final luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;

        // Apply highlight adjustment (for brighter pixels)
        if (highlights != 0 && luminance > 0.5) {
          // Fix: Use highlights directly (negative means brighter, positive means darker)
          // Stronger effect as we approach pure white (luminance = 1.0)
          final adjustment = 1.0 - (highlights * (luminance - 0.5) * 2);
          r = (r * adjustment).round().clamp(0, 255);
          g = (g * adjustment).round().clamp(0, 255);
          b = (b * adjustment).round().clamp(0, 255);
        }

        // Apply shadow adjustment (for darker pixels)
        if (shadows != 0 && luminance <= 0.5) {
          // Stronger effect as we approach pure black (luminance = 0.0)
          final factor = 1.0 + (shadows * (0.5 - luminance) * 2);
          r = (r * factor).round().clamp(0, 255);
          g = (g * factor).round().clamp(0, 255);
          b = (b * factor).round().clamp(0, 255);
        }

        // Set the adjusted pixel
        result.setPixel(x, y, img.ColorRgba8(r, g, b, a));
      }
    }

    return result;
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
