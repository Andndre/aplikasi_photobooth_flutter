import 'dart:io';
import 'dart:math' as math;
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

      // 3. Apply tone curve adjustments - after white balance but before other adjustments
      processedImage = _applyToneCurves(processedImage, preset);

      // 4. Apply blacks and whites
      if (preset.blacks != 0.0 || preset.whites != 0.0) {
        processedImage = _adjustBlacksWhites(
          processedImage,
          preset.blacks,
          preset.whites,
        );
      }

      // 5. Apply highlights and shadows
      if (preset.highlights != 0.0 || preset.shadows != 0.0) {
        processedImage = _adjustHighlightsShadows(
          processedImage,
          preset.highlights,
          preset.shadows,
        );
      }

      // 6. Apply color mixer adjustments
      processedImage = _applyColorMixer(processedImage, preset);

      // Apply Color Grading after color mixer but before black and white conversion
      if (preset.shadowsIntensity > 0 ||
          preset.midtonesIntensity > 0 ||
          preset.highlightsIntensity > 0) {
        processedImage = _applyColorGrading(processedImage, preset);
      }

      // 7. Black and White (if enabled)
      if (preset.blackAndWhite) {
        processedImage = img.grayscale(processedImage);
      }
      // Otherwise apply saturation adjustment (only if not in B&W mode)
      else if (preset.saturation != 0) {
        processedImage = _adjustSaturation(processedImage, preset.saturation);
      }

      // 8. Adjust brightness (-1.0 to 1.0)
      if (preset.brightness != 0) {
        processedImage = _adjustBrightness(processedImage, preset.brightness);
      }

      // 9. Adjust contrast (-1.0 to 1.0)
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

      // Add detail enhancements after basic adjustments but before border
      // Apply detail enhancements (sharpness, detail, noise reduction)
      if (preset.sharpness > 0 ||
          preset.detail > 0 ||
          preset.noiseReduction > 0) {
        processedImage = _applyDetailEnhancements(
          processedImage,
          preset.sharpness,
          preset.detail,
          preset.noiseReduction,
        );
      }

      // 10. Apply border if needed
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

    // Calculate the luminance histogram to analyze image brightness distribution
    final histogram = List<int>.filled(256, 0);

    // Build histogram
    for (var y = 0; y < result.height; y++) {
      for (var x = 0; x < result.width; x++) {
        final pixel = result.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();

        // Calculate luminance
        final luminance = ((0.299 * r + 0.587 * g + 0.114 * b)).round();
        if (luminance >= 0 && luminance < 256) {
          histogram[luminance]++;
        }
      }
    }

    // Apply to each pixel
    for (var y = 0; y < result.height; y++) {
      for (var x = 0; x < result.width; x++) {
        final pixel = result.getPixel(x, y);

        // Get color components
        int r = pixel.r.toInt();
        int g = pixel.g.toInt();
        int b = pixel.b.toInt();
        int a = pixel.a.toInt();

        // Calculate luminance
        final luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;

        // Whites: Controls the very brightest parts of the image
        // Proper whites adjustment - affects only the brightest areas
        if (whites != 0) {
          // Only apply to very bright areas (top 15% of brightness)
          if (luminance > 0.85) {
            // Calculate strength factor based on how close to pure white
            final strength = (luminance - 0.85) / 0.15;

            if (whites > 0) {
              // Increase brightness of light areas - push whites up
              final factor = 1.0 + (whites * 0.5 * strength);
              r = (r * factor).round().clamp(0, 255);
              g = (g * factor).round().clamp(0, 255);
              b = (b * factor).round().clamp(0, 255);
            } else {
              // Pull down whites (reduce brightness of bright areas)
              final factor = 1.0 + (whites * 0.3 * strength);
              r = (r * factor).round().clamp(0, 255);
              g = (g * factor).round().clamp(0, 255);
              b = (b * factor).round().clamp(0, 255);
            }
          }
        }

        // Blacks: Controls the very darkest parts of the image
        if (blacks != 0) {
          // Only apply to very dark areas (bottom 15% of brightness)
          if (luminance < 0.15) {
            // Calculate strength factor based on how close to pure black
            final strength = (0.15 - luminance) / 0.15;

            if (blacks > 0) {
              // Lift blacks (increase brightness of dark areas)
              final factor = 1.0 + (blacks * 0.5 * strength);
              r = (r * factor).round().clamp(0, 255);
              g = (g * factor).round().clamp(0, 255);
              b = (b * factor).round().clamp(0, 255);
            } else {
              // Crush blacks (decrease brightness of dark areas)
              final factor = 1.0 + (blacks * 0.5 * strength);
              r = (r * factor).round().clamp(0, 255);
              g = (g * factor).round().clamp(0, 255);
              b = (b * factor).round().clamp(0, 255);
            }
          }
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

        // Apply highlight adjustment - affects mid-high tones but not pure whites
        // (affects a narrower range than whites slider)
        if (highlights != 0 && luminance > 0.5 && luminance < 0.85) {
          // Calculate adjustment factor based on luminance and highlights value
          // Higher luminance = stronger effect, scaled by highlights parameter
          // Will affect mostly the mid-high tones, not the brightest areas
          final highlightStrength = (luminance - 0.5) / (0.85 - 0.5);
          final highlightsFactor = 1.0 - (highlights * highlightStrength * 0.7);

          r = (r * highlightsFactor).round().clamp(0, 255);
          g = (g * highlightsFactor).round().clamp(0, 255);
          b = (b * highlightsFactor).round().clamp(0, 255);
        }

        // Apply shadow adjustment (for darker pixels - but not pure blacks)
        if (shadows != 0 && luminance > 0.15 && luminance <= 0.5) {
          // Calculate shadow factor based on luminance and shadows value
          // Lower luminance = stronger effect, scaled by shadows parameter
          final shadowStrength = (0.5 - luminance) / (0.5 - 0.15);
          final shadowsFactor = 1.0 + (shadows * shadowStrength * 0.7);

          r = (r * shadowsFactor).round().clamp(0, 255);
          g = (g * shadowsFactor).round().clamp(0, 255);
          b = (b * shadowsFactor).round().clamp(0, 255);
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

  static img.Image _applyColorMixer(img.Image image, PresetModel preset) {
    // If no color mixer adjustments, return original image
    if (preset.redHue == 0.0 &&
        preset.redSaturation == 0.0 &&
        preset.redLuminance == 0.0 &&
        preset.greenHue == 0.0 &&
        preset.greenSaturation == 0.0 &&
        preset.greenLuminance == 0.0 &&
        preset.blueHue == 0.0 &&
        preset.blueSaturation == 0.0 &&
        preset.blueLuminance == 0.0) {
      return image;
    }

    // Create a copy to modify
    final result = img.Image.from(image);

    // Process each pixel
    for (var y = 0; y < result.height; y++) {
      for (var x = 0; x < result.width; x++) {
        final pixel = result.getPixel(x, y);

        // Get color components
        int r = pixel.r.toInt();
        int g = pixel.g.toInt();
        int b = pixel.b.toInt();
        int a = pixel.a.toInt();

        // Convert RGB to HSL
        final hslRed = _rgbToHsl(r, 0, 0);
        final hslGreen = _rgbToHsl(0, g, 0);
        final hslBlue = _rgbToHsl(0, 0, b);

        // Apply red channel adjustments
        if (r > 0 &&
            (preset.redHue != 0.0 ||
                preset.redSaturation != 0.0 ||
                preset.redLuminance != 0.0)) {
          final strength = r / 255.0; // Strength based on red component

          // Affect only the red channel
          double hue = hslRed[0] + (preset.redHue * 0.1 * strength);
          double sat = hslRed[1] * (1.0 + (preset.redSaturation * strength));
          double lum =
              hslRed[2] * (1.0 + (preset.redLuminance * 0.5 * strength));

          // Clamp values
          hue = (hue + 1.0) % 1.0; // Wrap hue
          sat = math.max(0.0, math.min(1.0, sat));
          lum = math.max(0.0, math.min(1.0, lum));

          // Convert back to RGB and apply adjustment to red channel
          final adjustedRed = _hslToRgb(hue, sat, lum)[0];
          r = ((r * (1.0 - strength)) + (adjustedRed * strength)).round().clamp(
            0,
            255,
          );
        }

        // Apply green channel adjustments
        if (g > 0 &&
            (preset.greenHue != 0.0 ||
                preset.greenSaturation != 0.0 ||
                preset.greenLuminance != 0.0)) {
          final strength = g / 255.0; // Strength based on green component

          // Affect only the green channel
          double hue = hslGreen[0] + (preset.greenHue * 0.1 * strength);
          double sat =
              hslGreen[1] * (1.0 + (preset.greenSaturation * strength));
          double lum =
              hslGreen[2] * (1.0 + (preset.greenLuminance * 0.5 * strength));

          // Clamp values
          hue = (hue + 1.0) % 1.0; // Wrap hue
          sat = math.max(0.0, math.min(1.0, sat));
          lum = math.max(0.0, math.min(1.0, lum));

          // Convert back to RGB and apply adjustment to green channel
          final adjustedGreen = _hslToRgb(hue, sat, lum)[1];
          g = ((g * (1.0 - strength)) + (adjustedGreen * strength))
              .round()
              .clamp(0, 255);
        }

        // Apply blue channel adjustments
        if (b > 0 &&
            (preset.blueHue != 0.0 ||
                preset.blueSaturation != 0.0 ||
                preset.blueLuminance != 0.0)) {
          final strength = b / 255.0; // Strength based on blue component

          // Affect only the blue channel
          double hue = hslBlue[0] + (preset.blueHue * 0.1 * strength);
          double sat = hslBlue[1] * (1.0 + (preset.blueSaturation * strength));
          double lum =
              hslBlue[2] * (1.0 + (preset.blueLuminance * 0.5 * strength));

          // Clamp values
          hue = (hue + 1.0) % 1.0; // Wrap hue
          sat = math.max(0.0, math.min(1.0, sat));
          lum = math.max(0.0, math.min(1.0, lum));

          // Convert back to RGB and apply adjustment to blue channel
          final adjustedBlue = _hslToRgb(hue, sat, lum)[2];
          b = ((b * (1.0 - strength)) + (adjustedBlue * strength))
              .round()
              .clamp(0, 255);
        }

        // Set the adjusted pixel
        result.setPixel(x, y, img.ColorRgba8(r, g, b, a));
      }
    }

    return result;
  }

  // Apply tone curves to the image
  static img.Image _applyToneCurves(img.Image image, PresetModel preset) {
    // If all curves are linear (default), skip processing
    if (_isLinearCurve(preset.rgbCurvePoints) &&
        _isLinearCurve(preset.redCurvePoints) &&
        _isLinearCurve(preset.greenCurvePoints) &&
        _isLinearCurve(preset.blueCurvePoints)) {
      return image;
    }

    // Create a copy to modify
    final result = img.Image.from(image);

    // Create lookup tables for faster processing
    final rgbLUT = _createLookupTable(preset.rgbCurvePoints);
    final redLUT = _createLookupTable(preset.redCurvePoints);
    final greenLUT = _createLookupTable(preset.greenCurvePoints);
    final blueLUT = _createLookupTable(preset.blueCurvePoints);

    // Apply curve to each pixel
    for (var y = 0; y < result.height; y++) {
      for (var x = 0; x < result.width; x++) {
        final pixel = result.getPixel(x, y);

        // Get color components
        int r = pixel.r.toInt();
        int g = pixel.g.toInt();
        int b = pixel.b.toInt();
        int a = pixel.a.toInt();

        // Apply RGB curve (affects all channels equally)
        r = rgbLUT[r];
        g = rgbLUT[g];
        b = rgbLUT[b];

        // Apply individual channel curves
        r = redLUT[r];
        g = greenLUT[g];
        b = blueLUT[b];

        // Set the adjusted pixel
        result.setPixel(x, y, img.ColorRgba8(r, g, b, a));
      }
    }

    return result;
  }

  // Check if curve is linear (default diagonal line) - now accepts CurvePointData
  static bool _isLinearCurve(List<CurvePointData> points) {
    if (points.length != 2) return false;

    // Check if points are at opposite corners
    return (points[0].point.dx < 1 &&
        points[0].point.dy > 255 &&
        points[1].point.dx > 255 &&
        points[1].point.dy < 1);
  }

  // Create lookup table from curve points for faster processing - now accepts CurvePointData
  static List<int> _createLookupTable(List<CurvePointData> curvePointsData) {
    const tableSize = 256;
    final lookupTable = List<int>.filled(tableSize, 0);

    // Extract the points from CurvePointData objects
    final points = curvePointsData.map((cp) => cp.point).toList();

    // For each possible input value (0-255)
    for (int i = 0; i < tableSize; i++) {
      // Convert to curve coordinates (x increases left to right, y increases bottom to top)
      final x = i.toDouble();

      // Find the two points that surround this x value
      Offset p1 = points.first;
      Offset p2 = points.last;

      for (int j = 0; j < points.length - 1; j++) {
        if (points[j].dx <= x && points[j + 1].dx >= x) {
          p1 = points[j];
          p2 = points[j + 1];
          break;
        }
      }

      // Linear interpolation between the two points
      double t = 0;
      if (p2.dx != p1.dx) {
        t = (x - p1.dx) / (p2.dx - p1.dx);
      }

      // Calculate the y value and convert to output range (0-255)
      // Note: y coordinate is inverted (0 at top, 255 at bottom)
      final y = p1.dy + t * (p2.dy - p1.dy);

      // Convert y from curve coordinates to actual output (invert y)
      lookupTable[i] = (255 - y).round().clamp(0, 255);
    }

    return lookupTable;
  }

  // Apply detail enhancements: sharpness, detail enhancement, noise reduction
  static img.Image _applyDetailEnhancements(
    img.Image image,
    double sharpness,
    double detail,
    double noiseReduction,
  ) {
    // Create a copy to modify
    var result = img.Image.from(image);

    // Apply noise reduction first (if any)
    if (noiseReduction > 0) {
      try {
        // Apply custom noise reduction with strength based on the noiseReduction value
        result = _applyNoiseReduction(result, noiseReduction);
      } catch (e) {
        print('Error applying noise reduction: $e');
      }
    }

    // Apply detail enhancement (mid-frequency contrast enhancement)
    if (detail > 0) {
      try {
        // Detail enhancement is a form of local contrast enhancement
        final strength = detail * 0.3; // Scale down for subtle effect
        result = _enhanceDetails(result, strength);
      } catch (e) {
        print('Error enhancing details: $e');
      }
    }

    // Apply sharpening last
    if (sharpness > 0) {
      try {
        // Instead of trying to use built-in sharpen, use our own implementation directly
        result = _applySimpleSharpening(result, sharpness);
      } catch (e) {
        print('Error applying sharpness: $e');
      }
    }

    return result;
  }

  // Custom implementation of noise reduction using local averaging with threshold
  static img.Image _applyNoiseReduction(img.Image image, double strength) {
    final result = img.Image.from(image);
    final width = image.width;
    final height = image.height;

    // Calculate radius based on strength (0-1)
    final radius = (strength * 2).round().clamp(1, 2);

    // Apply threshold-based noise reduction
    // For each pixel, calculate the average of surrounding pixels
    // and only apply smoothing where color variation is below a threshold
    for (int y = radius; y < height - radius; y++) {
      for (int x = radius; x < width - radius; x++) {
        // Sample the local neighborhood
        final neighborhoodSize = (2 * radius + 1) * (2 * radius + 1);
        int sumR = 0, sumG = 0, sumB = 0;
        List<int> valuesR = [], valuesG = [], valuesB = [];

        // Collect neighborhood pixel values
        for (int ny = -radius; ny <= radius; ny++) {
          for (int nx = -radius; nx <= radius; nx++) {
            final pixel = image.getPixel(x + nx, y + ny);
            final r = pixel.r.toInt();
            final g = pixel.g.toInt();
            final b = pixel.b.toInt();

            valuesR.add(r);
            valuesG.add(g);
            valuesB.add(b);

            sumR += r;
            sumG += g;
            sumB += b;
          }
        }

        // Calculate mean (average)
        final avgR = sumR / neighborhoodSize;
        final avgG = sumG / neighborhoodSize;
        final avgB = sumB / neighborhoodSize;

        // Get center pixel
        final centerPixel = image.getPixel(x, y);
        final centerR = centerPixel.r.toInt();
        final centerG = centerPixel.g.toInt();
        final centerB = centerPixel.b.toInt();

        // Calculate difference between center pixel and average
        final diffR = (centerR - avgR).abs();
        final diffG = (centerG - avgG).abs();
        final diffB = (centerB - avgB).abs();

        // Threshold for what's considered "noise"
        // Higher strength = more aggressive noise reduction
        final threshold =
            10 + 20 * (1 - strength); // 10-30 depending on strength

        // If the difference exceeds threshold, it's likely a detail rather than noise
        // Otherwise, apply smoothing by using the neighborhood average
        final newR = diffR > threshold ? centerR : avgR.round();
        final newG = diffG > threshold ? centerG : avgG.round();
        final newB = diffB > threshold ? centerB : avgB.round();

        result.setPixel(x, y, img.ColorRgb8(newR, newG, newB));
      }
    }

    return result;
  }

  // Simple sharpening implementation using a 3x3 kernel
  static img.Image _applySimpleSharpening(img.Image image, double sharpness) {
    final result = img.Image.from(image);
    final width = image.width;
    final height = image.height;

    // Scale sharpness to appropriate strength
    final strength = sharpness * 0.8; // 0.0 to 0.8

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        final center = image.getPixel(x, y);
        final top = image.getPixel(x, y - 1);
        final bottom = image.getPixel(x, y + 1);
        final left = image.getPixel(x - 1, y);
        final right = image.getPixel(x + 1, y);

        // Apply sharpening formula: center*5 - (top + right + bottom + left)
        // For each color channel
        int newR = _sharpenChannel(
          center.r.toInt(),
          top.r.toInt(),
          right.r.toInt(),
          bottom.r.toInt(),
          left.r.toInt(),
          strength,
        );
        int newG = _sharpenChannel(
          center.g.toInt(),
          top.g.toInt(),
          right.g.toInt(),
          bottom.g.toInt(),
          left.g.toInt(),
          strength,
        );
        int newB = _sharpenChannel(
          center.b.toInt(),
          top.b.toInt(),
          right.b.toInt(),
          bottom.b.toInt(),
          left.b.toInt(),
          strength,
        );

        result.setPixel(x, y, img.ColorRgb8(newR, newG, newB));
      }
    }

    return result;
  }

  // Helper for sharpening individual color channels
  static int _sharpenChannel(
    int center,
    int top,
    int right,
    int bottom,
    int left,
    double strength,
  ) {
    // Sharpening formula: center + strength * (center*5 - center - top - right - bottom - left)
    final sharpened =
        center +
        (strength * (center * 5 - center - top - right - bottom - left))
            .round();
    return sharpened.clamp(0, 255);
  }

  // Detail enhancement through local contrast enhancement
  static img.Image _enhanceDetails(img.Image image, double strength) {
    final result = img.Image.from(image);
    final width = image.width;
    final height = image.height;

    // Apply a simplified CLAHE-like effect (Contrast Limited Adaptive Histogram Equalization)
    // This enhances local details without extreme contrast changes
    for (int y = 2; y < height - 2; y++) {
      for (int x = 2; x < width - 2; x++) {
        final center = image.getPixel(x, y);

        // Calculate local average in a 5x5 area
        int sumR = 0, sumG = 0, sumB = 0;
        int count = 0;

        for (int ny = y - 2; ny <= y + 2; ny++) {
          for (int nx = x - 2; nx <= x + 2; nx++) {
            if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
              final pixel = image.getPixel(nx, ny);
              sumR += pixel.r.toInt();
              sumG += pixel.g.toInt();
              sumB += pixel.b.toInt();
              count++;
            }
          }
        }

        final avgR = sumR / count;
        final avgG = sumG / count;
        final avgB = sumB / count;

        // Enhance local contrast for detail perception
        final diffR = (center.r.toInt() - avgR) * strength;
        final diffG = (center.g.toInt() - avgG) * strength;
        final diffB = (center.b.toInt() - avgB) * strength;

        final newR = (center.r.toInt() + diffR).round().clamp(0, 255);
        final newG = (center.g.toInt() + diffG).round().clamp(0, 255);
        final newB = (center.b.toInt() + diffB).round().clamp(0, 255);

        result.setPixel(x, y, img.ColorRgb8(newR, newG, newB));
      }
    }

    return result;
  }

  // Apply color grading (shadows, midtones, highlights)
  static img.Image _applyColorGrading(img.Image image, PresetModel preset) {
    // Create a copy to modify
    final result = img.Image.from(image);

    // Apply to each pixel
    for (var y = 0; y < result.height; y++) {
      for (var x = 0; x < result.width; x++) {
        final pixel = result.getPixel(x, y);

        // Get color components
        int r = pixel.r.toInt();
        int g = pixel.g.toInt();
        int b = pixel.b.toInt();
        int a = pixel.a.toInt();

        // Calculate luminance to determine if pixel is shadow, midtone or highlight
        final luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;

        // Apply color grading based on luminance range
        // Apply shadows color (dark areas)
        if (luminance < 0.33 && preset.shadowsIntensity > 0) {
          final strength = preset.shadowsIntensity * (1.0 - luminance / 0.33);
          final adjustedRGB = _applyColorToPixel(
            r,
            g,
            b,
            preset.shadowsColor,
            strength,
          );
          r = adjustedRGB[0];
          g = adjustedRGB[1];
          b = adjustedRGB[2];
        }

        // Apply midtones color (mid-brightness areas)
        if (luminance >= 0.33 &&
            luminance <= 0.66 &&
            preset.midtonesIntensity > 0) {
          // Peak at 0.5, fade toward ends
          final midPoint = 0.5;
          final distance = (luminance - midPoint).abs();
          final maxDistance =
              0.17; // Distance from 0.5 to 0.33 or 0.66 (slightly adjusted)
          final strength =
              preset.midtonesIntensity * (1.0 - distance / maxDistance);
          final adjustedRGB = _applyColorToPixel(
            r,
            g,
            b,
            preset.midtonesColor,
            strength,
          );
          r = adjustedRGB[0];
          g = adjustedRGB[1];
          b = adjustedRGB[2];
        }

        // Apply highlights color (bright areas)
        if (luminance > 0.66 && preset.highlightsIntensity > 0) {
          final strength =
              preset.highlightsIntensity * ((luminance - 0.66) / 0.34);
          final adjustedRGB = _applyColorToPixel(
            r,
            g,
            b,
            preset.highlightsColor,
            strength,
          );
          r = adjustedRGB[0];
          g = adjustedRGB[1];
          b = adjustedRGB[2];
        }

        // Apply color balance if not zero
        if (preset.colorBalance != 0) {
          // Shift colors toward shadows or highlights
          if (preset.colorBalance > 0) {
            // Bias toward highlights color
            final strength = preset.colorBalance * luminance * 0.5;
            final adjustedRGB = _applyColorToPixel(
              r,
              g,
              b,
              preset.highlightsColor,
              strength,
            );
            r = adjustedRGB[0];
            g = adjustedRGB[1];
            b = adjustedRGB[2];
          } else {
            // Bias toward shadows color
            final strength = -preset.colorBalance * (1.0 - luminance) * 0.5;
            final adjustedRGB = _applyColorToPixel(
              r,
              g,
              b,
              preset.shadowsColor,
              strength,
            );
            r = adjustedRGB[0];
            g = adjustedRGB[1];
            b = adjustedRGB[2];
          }
        }

        // Set the adjusted pixel
        result.setPixel(x, y, img.ColorRgba8(r, g, b, a));
      }
    }

    return result;
  }

  // Helper to apply a color with strength to RGB values
  static List<int> _applyColorToPixel(
    int inR,
    int inG,
    int inB,
    Color colorToApply,
    double strength,
  ) {
    // Convert target color to HSL
    final hsl = _rgbToHsl(
      colorToApply.red,
      colorToApply.green,
      colorToApply.blue,
    );

    // Convert current pixel to HSL
    final pixelHsl = _rgbToHsl(inR, inG, inB);

    // Blend hue and saturation, keeping original luminance
    final blendedHsl = [
      _lerpDouble(pixelHsl[0], hsl[0], strength),
      _lerpDouble(pixelHsl[1], math.min(1.0, hsl[1] * 1.5), strength),
      pixelHsl[2], // Keep original luminance to preserve image brightness
    ];

    // Convert back to RGB
    final rgb = _hslToRgb(blendedHsl[0], blendedHsl[1], blendedHsl[2]);

    return [rgb[0], rgb[1], rgb[2]];
  }

  // Helper for linear interpolation
  static double _lerpDouble(double a, double b, double t) {
    return a + (b - a) * t;
  }
}
