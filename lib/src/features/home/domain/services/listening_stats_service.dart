import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/battery_saver_service.dart';

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

class ListeningStatsService {
  static const String _keyListeningTimeSeconds = 'daily_listening_time_seconds';
  static const String _legacyKeyListeningTimeMinutes = 'daily_listening_time';
  static const String _keySongPlays = 'daily_song_plays';
  static const String _keyUniqueSongs = 'daily_unique_songs';
  static const String _keyLastResetDate = 'last_reset_date';
  static const String _keyHistoryPrefix = 'stats_history_'; // Prefix for daily history

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

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _checkAndResetDaily();
    await _loadTodayStats();
    _isInitialized = true;
    _scheduleMidnightReset();
    _emitSnapshot();
  }

  bool get isInitialized => _isInitialized;

  Future<void> _checkAndResetDaily() async {
    final lastReset = _prefs.getString(_keyLastResetDate);
    final today = _getTodayKey();

    if (lastReset != today) {
      await _resetStats(today);
    }
  }

  Future<void> _resetStats(String todayKey) async {
    // Save yesterday's stats to history before resetting
    final lastReset = _prefs.getString(_keyLastResetDate);
    if (lastReset != null && lastReset != todayKey) {
      await _saveHistoricalStats(lastReset);
    }

    // Clean up old historical data (older than 30 days)
    await _cleanOldHistory();

    // Reset today's stats
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

  void _ensureFreshDaySync() {
    if (!_isInitialized) return;
    final lastReset = _prefs.getString(_keyLastResetDate);
    final today = _getTodayKey();
    if (lastReset != today) {
      // Reset immediately; persistence happens inside _resetStats
      unawaited(_resetStats(today));
    }
  }

  Future<void> startListening(String songId) async {
    if (!_isInitialized) return;
    if (!BatterySaverService.instance.shouldTrackStats) return;
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

  Future<void> stopListening() async {
    if (!BatterySaverService.instance.shouldTrackStats) return;
    await _finalizeSession(clearSongId: true);
  }

  Future<void> pauseListening() async {
    if (!BatterySaverService.instance.shouldTrackStats) return;
    await _finalizeSession(clearSongId: false);
  }

  Future<void> resumeListening() async {
    if (!_isInitialized) return;
    if (!BatterySaverService.instance.shouldTrackStats) return;
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

  Future<void> _saveTodayStats() async {
    if (!_isInitialized) return;
    await _prefs.setInt(_keyListeningTimeSeconds, _todayListeningTime.inSeconds);
    await _prefs.setStringList(_keyUniqueSongs, _todayUniqueSongs.toList());
    await _prefs.setInt(_keySongPlays, _todaySongPlays);
    await _prefs.setString(_keyLastResetDate, _getTodayKey());
  }

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

  Duration getTodayListeningTime() {
    _ensureFreshDaySync();
    if (_sessionStopwatch.isRunning) {
      return _todayListeningTime + _sessionStopwatch.elapsed;
    }
    return _todayListeningTime;
  }

  int getTodaySongPlays() {
    _ensureFreshDaySync();
    return _todaySongPlays;
  }

  int getTodayUniqueSongsCount() {
    _ensureFreshDaySync();
    return _todayUniqueSongs.length;
  }

  String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> refreshStats() async {
    if (!_isInitialized) return;
    await _checkAndResetDaily();
    await _loadTodayStats();
  }

  void _emitSnapshot() {
    statsNotifier.value = ListeningStatsSnapshot(
      listeningTime: getTodayListeningTime(),
      songPlays: _todaySongPlays,
      uniqueSongs: _todayUniqueSongs.length,
    );
  }

  Future<Map<String, dynamic>> getWeeklyStats() async {
    return {
      'totalMinutes': getTodayListeningTime().inMinutes * 7,
      'uniqueSongs': _todayUniqueSongs.length,
      'songPlays': _todaySongPlays,
    };
  }

  // Save historical stats for a specific date
  Future<void> _saveHistoricalStats(String dateKey) async {
    if (!_isInitialized) return;
    
    final historyData = {
      'listeningTimeSeconds': _todayListeningTime.inSeconds,
      'songPlays': _todaySongPlays,
      'uniqueSongs': _todayUniqueSongs.length,
    };
    
    await _prefs.setString(
      '$_keyHistoryPrefix$dateKey',
      json.encode(historyData),
    );
  }

  // Clean up stats older than 30 days
  Future<void> _cleanOldHistory() async {
    if (!_isInitialized) return;
    
    final now = DateTime.now();
    final cutoffDate = now.subtract(const Duration(days: 30));
    
    final allKeys = _prefs.getKeys();
    for (final key in allKeys) {
      if (key.startsWith(_keyHistoryPrefix)) {
        final dateStr = key.substring(_keyHistoryPrefix.length);
        try {
          final parts = dateStr.split('-');
          if (parts.length == 3) {
            final date = DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
            if (date.isBefore(cutoffDate)) {
              await _prefs.remove(key);
            }
          }
        } catch (e) {
          // Invalid date format, skip
        }
      }
    }
  }

  // Get stats for last 7 days (week)
  Future<Map<String, dynamic>> getWeekStats() async {
    if (!_isInitialized) return {'duration': Duration.zero, 'songPlays': 0, 'uniqueSongs': 0};
    
    final now = DateTime.now();
    int totalSeconds = 0;
    int totalSongPlays = 0;
    final Set<String> allUniqueSongs = {};
    
    // Include today's stats
    totalSeconds += getTodayListeningTime().inSeconds;
    totalSongPlays += _todaySongPlays;
    allUniqueSongs.addAll(_todayUniqueSongs);
    
    // Get last 6 days of historical data
    for (int i = 1; i < 7; i++) {
      final date = now.subtract(Duration(days: i));
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final historyJson = _prefs.getString('$_keyHistoryPrefix$dateKey');
      
      if (historyJson != null) {
        try {
          final data = json.decode(historyJson) as Map<String, dynamic>;
          totalSeconds += (data['listeningTimeSeconds'] as int? ?? 0);
          totalSongPlays += (data['songPlays'] as int? ?? 0);
          // Note: We don't have individual song IDs in history, so uniqueSongs is approximate
        } catch (e) {
          // Invalid JSON, skip
        }
      }
    }
    
    return {
      'duration': Duration(seconds: totalSeconds),
      'songPlays': totalSongPlays,
      'uniqueSongs': allUniqueSongs.length, // Only counts today's unique songs
    };
  }

  // Get stats for last 30 days (month)
  Future<Map<String, dynamic>> getMonthStats() async {
    if (!_isInitialized) return {'duration': Duration.zero, 'songPlays': 0, 'uniqueSongs': 0};
    
    final now = DateTime.now();
    int totalSeconds = 0;
    int totalSongPlays = 0;
    final Set<String> allUniqueSongs = {};
    
    // Include today's stats
    totalSeconds += getTodayListeningTime().inSeconds;
    totalSongPlays += _todaySongPlays;
    allUniqueSongs.addAll(_todayUniqueSongs);
    
    // Get last 29 days of historical data
    for (int i = 1; i < 30; i++) {
      final date = now.subtract(Duration(days: i));
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final historyJson = _prefs.getString('$_keyHistoryPrefix$dateKey');
      
      if (historyJson != null) {
        try {
          final data = json.decode(historyJson) as Map<String, dynamic>;
          totalSeconds += (data['listeningTimeSeconds'] as int? ?? 0);
          totalSongPlays += (data['songPlays'] as int? ?? 0);
        } catch (e) {
          // Invalid JSON, skip
        }
      }
    }
    
    return {
      'duration': Duration(seconds: totalSeconds),
      'songPlays': totalSongPlays,
      'uniqueSongs': allUniqueSongs.length, // Only counts today's unique songs
    };
  }
}
