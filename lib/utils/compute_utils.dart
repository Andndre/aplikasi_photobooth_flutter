import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:photobooth/models/preset_model.dart';
import 'package:photobooth/services/image_processor.dart';

/// Helper class for executing heavy operations using compute
class ComputeUtils {
  /// Process a single image in a separate isolate using compute
  static Future<File?> processImageInIsolate(
    File imageFile,
    PresetModel preset,
  ) async {
    try {
      return await compute<Map<String, dynamic>, File?>((params) {
        final file = File(params['imagePath'] as String);
        final presetData = params['preset'] as PresetModel;
        return ImageProcessor.processImage(file, presetData);
      }, {'imagePath': imageFile.path, 'preset': preset});
    } catch (e) {
      print('Error in processImageInIsolate: $e');
      return null;
    }
  }

  /// Process multiple images in a separate isolate using compute
  static Future<List<File>> batchProcessImagesInIsolate(
    List<File> imageFiles,
    PresetModel preset,
  ) async {
    try {
      return await compute<Map<String, dynamic>, List<File>>(
        (params) {
          final List<String> photoPaths = List<String>.from(
            params['photoPaths'],
          );
          final List<File> photos = photoPaths.map((p) => File(p)).toList();
          final PresetModel presetData = params['preset'];

          return ImageProcessor.batchProcessImagesWithProgress(
            photos,
            presetData,
            null, // Progress callback doesn't work in compute
          );
        },
        {
          'photoPaths': imageFiles.map((f) => f.path).toList(),
          'preset': preset,
        },
      );
    } catch (e) {
      print('Error in batchProcessImagesInIsolate: $e');
      // Return original files in case of error
      return imageFiles;
    }
  }

  /// Create GIF in a separate isolate using compute
  static Future<File?> createGifInIsolate({
    required List<String> imagePaths,
    required String outputPath,
  }) async {
    try {
      return await compute<Map<String, dynamic>, File?>((params) {
        final paths = List<String>.from(params['imagePaths']);
        final output = params['outputPath'] as String;
        return ImageProcessor.createOptimizedGif(
          images: paths,
          outputPath: output,
          progressCallback: null, // Not available in compute
        );
      }, {'imagePaths': imagePaths, 'outputPath': outputPath});
    } catch (e) {
      print('Error in createGifInIsolate: $e');
      return null;
    }
  }
}
