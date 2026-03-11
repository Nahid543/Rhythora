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
  static const int _maxPoolSize = 400; // limit scoring work for huge libraries

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

    if (!shouldRegenerate) {
      debugPrint('Using cached $type mix');
      return _cachedMixes[type]!;
    }

    debugPrint('Generating new $type mix...');

    final pool = _preprocessSongs(allSongs);
    List<Song> generatedMix;
    switch (type) {
      case MixType.chillEvening:
        generatedMix = await _generateChillMixAsync(pool, maxSongs);
        break;
      case MixType.energyBoost:
        generatedMix = await _generateEnergyMixAsync(pool, maxSongs);
        break;
      case MixType.focusMode:
        generatedMix = await _generateFocusMixAsync(pool, maxSongs, recentlyPlayed);
        break;
    }

    _cachedMixes[type] = generatedMix;
    _lastGenerationTime = DateTime.now();

    await _saveMixToPreferences(type, generatedMix);

    debugPrint('✅ Generated ${generatedMix.length} songs for $type');
    return generatedMix;
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

  static Future<void> _clearPersistedMixes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final type in MixType.values) {
        await prefs.remove('mix_${type.name}');
        await prefs.remove('mix_${type.name}_time');
      }
      debugPrint('Cleared persisted mix caches');
    } catch (e) {
      debugPrint('Error clearing persisted mix caches: $e');
    }
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

  static Future<void> clearAllCaches() async {
    clearCache(null);
    await _clearPersistedMixes();
  }

  static List<SongProfile> _preprocessSongs(List<Song> songs) {
    // Instead of randomly capping the pool, we process all songs but keep only the basics
    return songs
        .map(
          (s) => SongProfile(
            song: s,
            text: '${s.title} ${s.artist} ${s.album}'.toLowerCase(),
          ),
        )
        .toList();
  }

  static Future<List<Song>> _generateChillMixAsync(List<SongProfile> songs, int maxSongs) async {
    final chillKeywords = [
      'chill', 'relax', 'acoustic', 'calm', 'soft', 'slow', 'ambient',
      'peace', 'quiet', 'mellow', 'smooth', 'sleep', 'lofi'
    ];
    final avoidKeywords = ['metal', 'rock', 'hard', 'scream', 'death', 'brutal', 'remix', 'club'];

    final List<_ScoredSong> scored = [];
    int count = 0;
    
    for (final profile in songs) {
      int score = _keywordScore(profile.text, chillKeywords, weight: 3);
      score -= _keywordScore(profile.text, avoidKeywords, weight: 4);

      final seconds = profile.song.duration.inSeconds;
      if (seconds >= 150 && seconds <= 420) score += 3;
      if (seconds < 120) score -= 2;

      scored.add(_ScoredSong(profile.song, score));
      
      count++;
      // Yield to main thread every 250 iterations to prevent UI lag on potato phones
      if (count % 250 == 0) await Future.delayed(Duration.zero);
    }

    return _selectTop(scored, maxSongs);
  }

  static Future<List<Song>> _generateEnergyMixAsync(List<SongProfile> songs, int maxSongs) async {
    final energyKeywords = [
      'energy', 'power', 'rock', 'metal', 'dance', 'edm', 'fast', 'pump',
      'fire', 'drop', 'bass', 'beat', 'hype', 'club', 'remix', 'gym', 'workout'
    ];
    final avoidKeywords = ['slow', 'acoustic', 'calm', 'relax', 'sleep', 'piano', 'ambient'];

    final List<_ScoredSong> scored = [];
    int count = 0;

    for (final profile in songs) {
      int score = _keywordScore(profile.text, energyKeywords, weight: 3);
      score -= _keywordScore(profile.text, avoidKeywords, weight: 4);

      final seconds = profile.song.duration.inSeconds;
      if (seconds >= 120 && seconds < 240) score += 3;
      if (seconds < 120) score -= 1;
      if (seconds > 300) score -= 2;

      scored.add(_ScoredSong(profile.song, score));

      count++;
      if (count % 250 == 0) await Future.delayed(Duration.zero);
    }

    return _selectTop(scored, maxSongs);
  }

  static Future<List<Song>> _generateFocusMixAsync(
    List<SongProfile> songs,
    int maxSongs,
    List<Song>? recentlyPlayed,
  ) async {
    final focusKeywords = [
      'instrumental', 'piano', 'study', 'focus', 'concentration',
      'classical', 'ambient', 'lofi', 'meditation', 'zen', 'work', 'code'
    ];
    final avoidKeywords = ['vocal', 'lyrics', 'sing', 'rap', 'live', 'club'];
    final recentArtists = recentlyPlayed?.map((s) => s.artist.toLowerCase()).toSet();

    final List<_ScoredSong> scored = [];
    int count = 0;

    for (final profile in songs) {
      int score = _keywordScore(profile.text, focusKeywords, weight: 4);
      score -= _keywordScore(profile.text, avoidKeywords, weight: 4);

      final seconds = profile.song.duration.inSeconds;
      if (seconds >= 180 && seconds <= 600) score += 3;

      if (recentArtists != null && recentArtists.contains(profile.song.artist.toLowerCase())) {
        score += 2; // Favor artists the user actually listens to
      }

      scored.add(_ScoredSong(profile.song, score));

      count++;
      if (count % 250 == 0) await Future.delayed(Duration.zero);
    }

    return _selectTop(scored, maxSongs);
  }

  static int _keywordScore(String text, List<String> keywords, {int weight = 1}) {
    int score = 0;
    for (final word in keywords) {
      if (text.contains(word)) score += weight;
    }
    return score;
  }

  static Future<List<Song>> _selectTop(List<_ScoredSong> scored, int maxSongs) async {
    // Sort yielding periodically just in case it's huge
    scored.sort((a, b) => b.score.compareTo(a.score));
    
    final positive = scored.where((s) => s.score > 0).toList();
    final pool = positive.isNotEmpty ? positive : scored;

    // Give it a tiny shuffle within the top tier so it isn't literally the exact same 30 songs every day
    final take = pool.take(maxSongs * 2).map((e) => e.song).toList();
    take.shuffle(Random());
    return take.take(maxSongs).toList();
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

class SongProfile {
  SongProfile({
    required this.song,
    required this.text,
  });

  final Song song;
  final String text;
}

class _ScoredSong {
  _ScoredSong(this.song, this.score);
  final Song song;
  final int score;
}
