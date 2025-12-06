import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../library/domain/entities/song.dart';

enum MixType {
  chillEvening,
  energyBoost,
  focusMode,
}

class MixGenerator {
  static final Map<MixType, List<Song>> _cachedMixes = {};
  static DateTime? _lastGenerationTime;

  static Future<List<Song>> generateMix({
    required MixType type,
    required List<Song> allSongs,
    List<Song>? recentlyPlayed,
    int maxSongs = 30,
    bool forceRegenerate = false,
  }) async {
    if (allSongs.isEmpty) return [];

    final shouldRegenerate = forceRegenerate ||
        _cachedMixes[type] == null ||
        _lastGenerationTime == null ||
        DateTime.now().difference(_lastGenerationTime!) > const Duration(hours: 24);

    if (shouldRegenerate) {
      debugPrint('Generating new $type mix...');
      
      await Future.delayed(const Duration(milliseconds: 500));

      List<Song> generatedMix;
      switch (type) {
        case MixType.chillEvening:
          generatedMix = _generateChillMix(allSongs, maxSongs);
          break;
        case MixType.energyBoost:
          generatedMix = _generateEnergyMix(allSongs, maxSongs);
          break;
        case MixType.focusMode:
          generatedMix = _generateFocusMix(allSongs, maxSongs, recentlyPlayed);
          break;
      }

      _cachedMixes[type] = generatedMix;
      _lastGenerationTime = DateTime.now();
      
      await _saveMixToPreferences(type, generatedMix);
      
      debugPrint('✅ Generated ${generatedMix.length} songs for $type');
      return generatedMix;
    }

    debugPrint('Using cached $type mix');
    return _cachedMixes[type]!;
  }

  static Future<void> _saveMixToPreferences(MixType type, List<Song> mix) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mixJson = mix.map((s) => s.toJson()).toList();
      await prefs.setString('mix_${type.name}', jsonEncode(mixJson));
      await prefs.setString('mix_${type.name}_time', DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('Error saving mix: $e');
    }
  }

  static Future<List<Song>?> loadMixFromPreferences(MixType type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mixJson = prefs.getString('mix_${type.name}');
      final timeString = prefs.getString('mix_${type.name}_time');
      
      if (mixJson != null && timeString != null) {
        final savedTime = DateTime.parse(timeString);
        if (DateTime.now().difference(savedTime) < const Duration(hours: 24)) {
          final List<dynamic> decoded = jsonDecode(mixJson);
          final mix = decoded.map((json) => Song.fromJson(json)).toList();
          _cachedMixes[type] = mix;
          _lastGenerationTime = savedTime;
          return mix;
        }
      }
    } catch (e) {
      debugPrint('Error loading mix: $e');
    }
    return null;
  }

  static void clearCache(MixType? type) {
    if (type != null) {
      _cachedMixes.remove(type);
      debugPrint('Cleared cache for $type');
    } else {
      _cachedMixes.clear();
      _lastGenerationTime = null;
      debugPrint('Cleared all mix caches');
    }
  }

  static List<Song> _generateChillMix(List<Song> songs, int maxSongs) {
    final chillKeywords = ['chill', 'relax', 'acoustic', 'calm', 'soft', 'slow', 'ambient', 'peace', 'quiet', 'mellow', 'smooth'];
    final avoidKeywords = ['metal', 'rock', 'hard', 'scream', 'death', 'brutal'];
    
    final scoredSongs = songs.map((song) {
      final searchText = '${song.title} ${song.artist} ${song.album}'.toLowerCase();
      
      int score = 0;
      for (var keyword in chillKeywords) {
        if (searchText.contains(keyword)) score += 3;
      }
      for (var keyword in avoidKeywords) {
        if (searchText.contains(keyword)) score -= 5;
      }
      
      if (song.duration.inSeconds > 180 && song.duration.inSeconds < 360) {
        score += 2;
      }
      
      return {'song': song, 'score': score};
    }).toList();

    scoredSongs.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    
    final topSongs = scoredSongs.take(maxSongs).map((item) => item['song'] as Song).toList();
    topSongs.shuffle(Random());
    
    return topSongs;
  }

  static List<Song> _generateEnergyMix(List<Song> songs, int maxSongs) {
    final energyKeywords = ['energy', 'power', 'rock', 'metal', 'dance', 'edm', 'fast', 'pump', 'fire', 'beast', 'drop', 'bass', 'beat', 'hype'];
    final avoidKeywords = ['slow', 'acoustic', 'calm', 'relax', 'sleep'];
    
    final scoredSongs = songs.map((song) {
      final searchText = '${song.title} ${song.artist} ${song.album}'.toLowerCase();
      
      int score = 0;
      for (var keyword in energyKeywords) {
        if (searchText.contains(keyword)) score += 3;
      }
      for (var keyword in avoidKeywords) {
        if (searchText.contains(keyword)) score -= 5;
      }
      
      if (song.duration.inSeconds < 240) {
        score += 2;
      }
      
      return {'song': song, 'score': score};
    }).toList();

    scoredSongs.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    
    final topSongs = scoredSongs.take(maxSongs).map((item) => item['song'] as Song).toList();
    topSongs.shuffle(Random());
    
    return topSongs;
  }

  static List<Song> _generateFocusMix(List<Song> songs, int maxSongs, List<Song>? recentlyPlayed) {
    final focusKeywords = ['instrumental', 'piano', 'study', 'focus', 'concentration', 'classical', 'ambient', 'lofi', 'meditation', 'zen'];
    final avoidKeywords = ['vocal', 'lyrics', 'sing', 'rap'];
    
    final scoredSongs = songs.map((song) {
      final searchText = '${song.title} ${song.artist} ${song.album}'.toLowerCase();
      
      int score = 0;
      for (var keyword in focusKeywords) {
        if (searchText.contains(keyword)) score += 3;
      }
      for (var keyword in avoidKeywords) {
        if (searchText.contains(keyword)) score -= 3;
      }
      
      if (song.duration.inSeconds > 240) {
        score += 2;
      }
      
      if (recentlyPlayed != null && recentlyPlayed.any((r) => r.artist == song.artist)) {
        score += 1;
      }
      
      return {'song': song, 'score': score};
    }).toList();

    scoredSongs.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    
    final topSongs = scoredSongs.take(maxSongs).map((item) => item['song'] as Song).toList();
    topSongs.shuffle(Random());
    
    return topSongs;
  }

  static MixInfo getMixInfo(MixType type) {
    switch (type) {
      case MixType.chillEvening:
        return MixInfo(
          title: 'Chill evening',
          subtitle: 'Soft tracks for focus & relax',
          description: 'Unwind with relaxing melodies perfect for a calm evening',
          icon: Icons.nightlight_rounded,
          gradientColors: const [Color(0xFF1E293B), Color(0xFF0F172A)],
        );
      
      case MixType.energyBoost:
        return MixInfo(
          title: 'Energy boost',
          subtitle: 'Upbeat songs from your library',
          description: 'Pump up the volume with high-energy tracks',
          icon: Icons.bolt_rounded,
          gradientColors: const [Color(0xFF7C3AED), Color(0xFF4C1D95)],
        );
      
      case MixType.focusMode:
        return MixInfo(
          title: 'Focus mode',
          subtitle: 'Instrumental tracks for deep work',
          description: 'Stay concentrated with peaceful instrumentals',
          icon: Icons.workspace_premium_rounded,
          gradientColors: const [Color(0xFF0EA5E9), Color(0xFF0C4A6E)],
        );
    }
  }
}

class MixInfo {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final List<Color> gradientColors;

  MixInfo({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.gradientColors,
  });
}
