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
        generatedMix = _generateChillMix(pool, maxSongs);
        break;
      case MixType.energyBoost:
        generatedMix = _generateEnergyMix(pool, maxSongs);
        break;
      case MixType.focusMode:
        generatedMix = _generateFocusMix(pool, maxSongs, recentlyPlayed);
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
    // Cap processing to avoid sluggishness on huge libraries
    final pool = songs.length > _maxPoolSize
        ? (List<Song>.from(songs)..shuffle()).take(_maxPoolSize).toList()
        : songs;

    return pool
        .map(
          (s) => SongProfile(
            song: s,
            text: '${s.title} ${s.artist} ${s.album}'.toLowerCase(),
          ),
        )
        .toList();
  }

  static List<Song> _generateChillMix(List<SongProfile> songs, int maxSongs) {
    final chillKeywords = [
      'chill',
      'relax',
      'acoustic',
      'calm',
      'soft',
      'slow',
      'ambient',
      'peace',
      'quiet',
      'mellow',
      'smooth',
      'sleep'
    ];
    final avoidKeywords = ['metal', 'rock', 'hard', 'scream', 'death', 'brutal'];

    final scored = songs.map((profile) {
      int score = _keywordScore(profile.text, chillKeywords, weight: 3);
      score -= _keywordScore(profile.text, avoidKeywords, weight: 4);

      final seconds = profile.song.duration.inSeconds;
      if (seconds >= 150 && seconds <= 420) score += 3;
      if (seconds < 120) score -= 2;

      return _ScoredSong(profile.song, score);
    }).toList();

    return _selectTop(scored, maxSongs);
  }

  static List<Song> _generateEnergyMix(List<SongProfile> songs, int maxSongs) {
    final energyKeywords = [
      'energy',
      'power',
      'rock',
      'metal',
      'dance',
      'edm',
      'fast',
      'pump',
      'fire',
      'drop',
      'bass',
      'beat',
      'hype',
      'club',
      'remix'
    ];
    final avoidKeywords = ['slow', 'acoustic', 'calm', 'relax', 'sleep', 'piano'];

    final scored = songs.map((profile) {
      int score = _keywordScore(profile.text, energyKeywords, weight: 3);
      score -= _keywordScore(profile.text, avoidKeywords, weight: 4);

      final seconds = profile.song.duration.inSeconds;
      if (seconds < 240) score += 3;
      if (seconds < 180) score += 1;
      if (seconds > 360) score -= 2;

      return _ScoredSong(profile.song, score);
    }).toList();

    return _selectTop(scored, maxSongs);
  }

  static List<Song> _generateFocusMix(
    List<SongProfile> songs,
    int maxSongs,
    List<Song>? recentlyPlayed,
  ) {
    final focusKeywords = [
      'instrumental',
      'piano',
      'study',
      'focus',
      'concentration',
      'classical',
      'ambient',
      'lofi',
      'meditation',
      'zen',
      'sleep'
    ];
    final avoidKeywords = ['vocal', 'lyrics', 'sing', 'rap', 'live', 'remix'];
    final recentArtists =
        recentlyPlayed?.map((s) => s.artist.toLowerCase()).toSet();

    final scored = songs.map((profile) {
      int score = _keywordScore(profile.text, focusKeywords, weight: 3);
      score -= _keywordScore(profile.text, avoidKeywords, weight: 3);

      final seconds = profile.song.duration.inSeconds;
      if (seconds >= 180 && seconds <= 480) score += 3;
      if (seconds > 480) score -= 1;

      if (recentArtists != null &&
          recentArtists.contains(profile.song.artist.toLowerCase())) {
        score += 1;
      }

      return _ScoredSong(profile.song, score);
    }).toList();

    return _selectTop(scored, maxSongs);
  }

  static int _keywordScore(String text, List<String> keywords,
      {int weight = 1}) {
    var score = 0;
    for (final word in keywords) {
      if (text.contains(word)) score += weight;
    }
    return score;
  }

  static List<Song> _selectTop(List<_ScoredSong> scored, int maxSongs) {
    scored.sort((a, b) => b.score.compareTo(a.score));
    final positive = scored.where((s) => s.score > 0).toList();
    final pool = positive.isNotEmpty ? positive : scored;

    final take = pool.take(maxSongs).map((e) => e.song).toList();
    take.shuffle(Random());
    return take;
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
