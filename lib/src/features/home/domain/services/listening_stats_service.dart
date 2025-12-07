import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ListeningStatsSnapshot {
  const ListeningStatsSnapshot({
    required this.listeningTime,
    required this.songPlays,
    required this.uniqueSongs,
  });

  final Duration listeningTime;
  final int songPlays;
  final int uniqueSongs;
}

/// Service to track user's listening statistics accurately
/// Tracks daily listening time, total song plays, and unique songs
class ListeningStatsService {
  static const String _keyListeningTimeSeconds = 'daily_listening_time_seconds';
  static const String _legacyKeyListeningTimeMinutes = 'daily_listening_time';
  static const String _keySongPlays = 'daily_song_plays';
  static const String _keyUniqueSongs = 'daily_unique_songs';
  static const String _keyLastResetDate = 'last_reset_date';

  late SharedPreferences _prefs;
  bool _isInitialized = false;

  final Stopwatch _sessionStopwatch = Stopwatch();
  Timer? _midnightResetTimer;
  final ValueNotifier<ListeningStatsSnapshot> statsNotifier =
      ValueNotifier<ListeningStatsSnapshot>(
    const ListeningStatsSnapshot(
      listeningTime: Duration.zero,
      songPlays: 0,
      uniqueSongs: 0,
    ),
  );

  Set<String> _todayUniqueSongs = {};
  int _todaySongPlays = 0;
  Duration _todayListeningTime = Duration.zero;
  String? _currentPlayingSongId;

  /// Initialize the service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _checkAndResetDaily();
    await _loadTodayStats();
    _isInitialized = true;
    _scheduleMidnightReset();
    _emitSnapshot();
  }

  bool get isInitialized => _isInitialized;

  /// Ensure stats are reset when a new day starts
  Future<void> _checkAndResetDaily() async {
    final lastReset = _prefs.getString(_keyLastResetDate);
    final today = _getTodayKey();

    if (lastReset != today) {
      await _resetStats(today);
    }
  }

  Future<void> _resetStats(String todayKey) async {
    _todayListeningTime = Duration.zero;
    _todaySongPlays = 0;
    _todayUniqueSongs.clear();
    _currentPlayingSongId = null;
    _sessionStopwatch
      ..reset()
      ..stop();

    await _prefs.setString(_keyLastResetDate, todayKey);
    await _saveTodayStats();
    _scheduleMidnightReset();
    _emitSnapshot();
  }

  void _scheduleMidnightReset() {
    _midnightResetTimer?.cancel();
    if (!_isInitialized) return;

    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final waitDuration = nextMidnight.difference(now);

    _midnightResetTimer = Timer(waitDuration, () async {
      await _resetStats(_getTodayKey());
    });
  }

  Future<void> _ensureFreshDay() async {
    if (!_isInitialized) return;
    await _checkAndResetDaily();
  }

  /// Start tracking a song session
  Future<void> startListening(String songId) async {
    if (!_isInitialized) return;
    await _ensureFreshDay();

    if (_currentPlayingSongId != null && _currentPlayingSongId != songId) {
      await _finalizeSession(clearSongId: true);
    }

    _currentPlayingSongId = songId;
    _sessionStopwatch
      ..reset()
      ..start();

    _todaySongPlays += 1;
    _todayUniqueSongs.add(songId);
    await _saveTodayStats();
    _emitSnapshot();
  }

  /// Stop tracking current session and save listening time
  Future<void> stopListening() async {
    await _finalizeSession(clearSongId: true);
  }

  /// Pause tracking (when user pauses playback)
  Future<void> pauseListening() async {
    await _finalizeSession(clearSongId: false);
  }

  /// Resume tracking (when user resumes playback)
  Future<void> resumeListening() async {
    if (!_isInitialized) return;
    await _ensureFreshDay();

    if (_currentPlayingSongId != null && !_sessionStopwatch.isRunning) {
      _sessionStopwatch
        ..reset()
        ..start();
    }
  }

  Future<void> _finalizeSession({required bool clearSongId}) async {
    if (!_isInitialized) return;
    await _ensureFreshDay();

    if (_sessionStopwatch.isRunning) {
      final elapsed = _sessionStopwatch.elapsed;
      _sessionStopwatch
        ..stop()
        ..reset();

      if (elapsed.inSeconds >= 3) {
        _todayListeningTime += elapsed;
      }
    }

    if (clearSongId) {
      _currentPlayingSongId = null;
    }

    await _saveTodayStats();
    _emitSnapshot();
  }

  /// Save current stats to storage (stores seconds for precision)
  Future<void> _saveTodayStats() async {
    if (!_isInitialized) return;
    await _prefs.setInt(_keyListeningTimeSeconds, _todayListeningTime.inSeconds);
    await _prefs.setStringList(_keyUniqueSongs, _todayUniqueSongs.toList());
    await _prefs.setInt(_keySongPlays, _todaySongPlays);
    await _prefs.setString(_keyLastResetDate, _getTodayKey());
  }

  /// Load today's stats from storage (supports legacy minutes key)
  Future<void> _loadTodayStats() async {
    final seconds = _prefs.getInt(_keyListeningTimeSeconds);
    if (seconds != null) {
      _todayListeningTime = Duration(seconds: seconds);
    } else {
      final minutes = _prefs.getInt(_legacyKeyListeningTimeMinutes) ?? 0;
      _todayListeningTime = Duration(minutes: minutes);
    }

    _todaySongPlays = _prefs.getInt(_keySongPlays) ?? 0;
    final songsList = _prefs.getStringList(_keyUniqueSongs) ?? [];
    _todayUniqueSongs = Set<String>.from(songsList);

    if (_todaySongPlays == 0 && _todayUniqueSongs.isNotEmpty) {
      _todaySongPlays = _todayUniqueSongs.length;
    }

    _emitSnapshot();
  }

  /// Get today's listening time (includes currently running session)
  Duration getTodayListeningTime() {
    if (_sessionStopwatch.isRunning) {
      return _todayListeningTime + _sessionStopwatch.elapsed;
    }
    return _todayListeningTime;
  }

  /// Get count of songs played today (includes repeats)
  int getTodaySongPlays() => _todaySongPlays;

  /// Get count of unique songs played today
  int getTodayUniqueSongsCount() => _todayUniqueSongs.length;

  /// Get today's date key (format: yyyy-MM-dd)
  String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Manual refresh stats (for pull-to-refresh)
  Future<void> refreshStats() async {
    if (!_isInitialized) return;
    await _checkAndResetDaily();
    await _loadTodayStats();
  }

  /// Update listeners with the latest snapshot
  void _emitSnapshot() {
    statsNotifier.value = ListeningStatsSnapshot(
      listeningTime: getTodayListeningTime(),
      songPlays: _todaySongPlays,
      uniqueSongs: _todayUniqueSongs.length,
    );
  }

  /// Get weekly stats (placeholder for future expansion)
  Future<Map<String, dynamic>> getWeeklyStats() async {
    return {
      'totalMinutes': getTodayListeningTime().inMinutes * 7,
      'uniqueSongs': _todayUniqueSongs.length,
      'songPlays': _todaySongPlays,
    };
  }
}
