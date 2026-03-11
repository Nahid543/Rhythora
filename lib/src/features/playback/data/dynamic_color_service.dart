import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../../core/theme/app_colors.dart';

class DynamicColorService extends ChangeNotifier {
  static final DynamicColorService instance = DynamicColorService._internal();

  DynamicColorService._internal();

  // Cache extracted colors to prevent re-processing the same image
  final Map<String, Color> _colorCache = {};
  
  // Current dominant color (defaults to primary app color)
  Color _dominantColor = AppColors.primary;
  Color get dominantColor => _dominantColor;

  bool _isExtracting = false;

  /// Extracts the dominant color from a local image file.
  /// If [imagePath] is null or doesn't exist, it falls back to the default color.
  Future<void> updateDominantColor(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) {
      _resetToDefault();
      return;
    }

    // Check cache first
    if (_colorCache.containsKey(imagePath)) {
      _dominantColor = _colorCache[imagePath]!;
      notifyListeners();
      return;
    }

    final file = File(imagePath);
    if (!await file.exists()) {
      _resetToDefault();
      return;
    }

    // Prevent concurrent extractions from piling up
    if (_isExtracting) return;
    _isExtracting = true;

    try {
      // Create image provider from file
      final imageProvider = FileImage(file);
      
      // Extract palette in the background
      final palette = await PaletteGenerator.fromImageProvider(
        imageProvider,
        maximumColorCount: 16, // Keep it low for performance
      ).timeout(const Duration(seconds: 3));

      // Prefer vibrant/dominant colors, fall back to primary if generation fails
      final extractedColor = palette.dominantColor?.color 
          ?? palette.vibrantColor?.color 
          ?? palette.mutedColor?.color 
          ?? AppColors.primary;

      // Cache the result
      _colorCache[imagePath] = extractedColor;
      
      _dominantColor = extractedColor;
      notifyListeners();
      
    } catch (e) {
      debugPrint('[DynamicColorService] Failed to extract color: $e');
      _resetToDefault();
    } finally {
      _isExtracting = false;
    }
  }

  void _resetToDefault() {
    if (_dominantColor != AppColors.primary) {
      _dominantColor = AppColors.primary;
      notifyListeners();
    }
  }

  /// Clears the color cache (useful if the app uses too much memory)
  void clearCache() {
    _colorCache.clear();
  }
}
