import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/home/domain/mix_generator.dart';
import '../../features/library/data/local_music_loader.dart';
import '../../features/playback/data/audio_player_manager.dart';

class CacheService {
  CacheService._();

  static final CacheService instance = CacheService._();

  Future<void> clearAllCaches() async {
    await _clearLibraryAndArtworkCache();
    await _clearPlayerCache();
    await _clearMixCache();
    await _clearTempDirectories();
  }

  Future<void> _clearLibraryAndArtworkCache() async {
    try {
      await LocalMusicLoader.instance.clearCache();
    } catch (e) {
      debugPrint('CacheService: Failed to clear library cache: $e');
    }
  }

  Future<void> _clearPlayerCache() async {
    try {
      await AudioPlayerManager.instance.clearCache();
    } catch (e) {
      debugPrint('CacheService: Failed to clear player cache: $e');
    }
  }

  Future<void> _clearMixCache() async {
    try {
      await MixGenerator.clearAllCaches();
    } catch (e) {
      debugPrint('CacheService: Failed to clear mix cache: $e');
    }
  }

  Future<void> _clearTempDirectories() async {
    try {
      final tempDir = await getTemporaryDirectory();
      await _deleteDirectoryContents(tempDir);
    } catch (e) {
      debugPrint('CacheService: Failed to clear temp directory: $e');
    }
  }

  Future<void> _deleteDirectoryContents(Directory dir) async {
    if (!dir.existsSync()) return;

    await for (final entity in dir.list(recursive: false, followLinks: false)) {
      try {
        if (entity is File) {
          await entity.delete();
        } else if (entity is Directory) {
          await entity.delete(recursive: true);
        }
      } catch (e) {
        debugPrint('CacheService: Failed to delete ${entity.path}: $e');
      }
    }
  }
}
