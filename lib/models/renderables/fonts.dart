import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photobooth/models/layout_model.dart';
import 'package:photobooth/models/renderables/text_element.dart';

class Fonts {
  static Map<String, String> fontPaths = {};
  static List<String> defaultFonts = [
    'Arial',
    'Times New Roman',
    'Helvetica',
    'Courier New',
  ];
  static Set<String> loadedFonts = {};
  static bool isPathsLoaded = false;
  static Future<void> loadSystemFonts() async {
    if (!Platform.isWindows) {
      return;
    }

    if (isPathsLoaded) return;

    try {
      Set<String> fontNames = {};

      // Load fonts from both system and user directories
      final directories = [
        Directory('C:\\Windows\\Fonts'),
        Directory(
          '${Platform.environment['USERPROFILE']}\\AppData\\Local\\Microsoft\\Windows\\Fonts',
        ),
      ];

      for (var dir in directories) {
        if (await dir.exists()) {
          List<FileSystemEntity> fontFiles = await dir.list().toList();

          for (var file in fontFiles) {
            if (file is File) {
              String path = file.path.toLowerCase();
              if (path.endsWith('.ttf') ||
                  path.endsWith('.otf') ||
                  path.endsWith('.ttc')) {
                String rawName = file.path.split('\\').last;
                String fontName = _extractFontFamilyName(rawName);

                if (fontName.isNotEmpty) {
                  fontNames.add(fontName);
                  fontPaths[fontName] = file.path;

                  String rawNameWithoutExt = rawName.replaceAll(
                    RegExp(r'\.(ttf|otf|ttc)$', caseSensitive: false),
                    '',
                  );
                  if (rawNameWithoutExt.isNotEmpty) {
                    fontNames.add(rawNameWithoutExt);
                    fontPaths[rawNameWithoutExt] = file.path;
                  }
                }
              }
            }
          }
        }
      }

      print('Discovered ${fontPaths.length} system fonts');
    } catch (e) {
      print('Error searching for system fonts: $e');
    }
  }

  static Future<void> preloadFont(String fontFamily, bool isGoogleFont) async {
    if (Fonts.loadedFonts.contains(fontFamily)) return;

    try {
      if (isGoogleFont) {
        GoogleFonts.getFont(fontFamily);
        Fonts.loadedFonts.add(fontFamily);
      } else {
        await Fonts._loadSystemFont(fontFamily);
      }
    } catch (e) {
      print('Error loading font $fontFamily: $e');
    }
  }

  static Future<void> loadUsedFonts({required LayoutModel layout}) async {
    List<TextElement> textElements = layout.allTextElements;

    for (final textElement in textElements) {
      print("Font used: ${textElement.fontFamily}");
      // Skip if already loaded
      if (Fonts.loadedFonts.contains(textElement.fontFamily)) {
        continue;
      }

      try {
        await preloadFont(textElement.fontFamily, textElement.isGoogleFont);
      } catch (e) {
        print('Error loading font ${textElement.fontFamily}: $e');
      }
    }

    return;
  }

  static Future<void> _loadSystemFont(String fontFamily) async {
    if (!isPathsLoaded) {
      await loadSystemFonts();
      isPathsLoaded = true;
    }
    try {
      final fontFile = File(fontPaths[fontFamily]!);
      if (await fontFile.exists()) {
        final fontLoader = FontLoader(fontFamily);
        final bytes = await fontFile.readAsBytes();
        fontLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
        await fontLoader.load();
        loadedFonts.add(fontFamily);
      }
    } catch (e) {
      print('Error preloading font $fontFamily: $e');
    }
  }

  static String _extractFontFamilyName(String filename) {
    // Remove file extension
    String name = filename.replaceAll(
      RegExp(r'\.(ttf|otf|ttc)$', caseSensitive: false),
      '',
    );

    // Convert special characters to spaces
    name = name.replaceAll(RegExp(r'[-_]'), ' ');

    // Split into words
    List<String> words = name.split(' ');

    // Convert to title case and handle special cases
    words =
        words
            .map((word) {
              if (word.isEmpty) return '';
              // Keep original casing for single characters (like iTerm)
              if (word.length == 1) return word;
              // Capitalize first letter, lowercase rest
              return word[0].toUpperCase() + word.substring(1).toLowerCase();
            })
            .where((w) => w.isNotEmpty)
            .toList();

    // Join words back together
    return words.join(' ');
  }
}
