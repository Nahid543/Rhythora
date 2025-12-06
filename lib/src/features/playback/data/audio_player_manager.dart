// lib/src/features/playback/data/audio_player_manager.dart

import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../library/domain/entities/song.dart';
import '../domain/repeat_mode.dart';

import '../../../app/rhythora_app.dart' show listeningStatsService;

class AudioPlayerManager {
  AudioPlayerManager._internal() {
    _init();
  }

  static final AudioPlayerManager instance = AudioPlayerManager._internal();

  final AudioPlayer _player = AudioPlayer();

  ConcatenatingAudioSource? _currentPlaylist;
  List<Song>? _currentQueue;
  String? _defaultArtworkPath;
  bool _isManualSeek = false;
  bool _isRestoringState = false;

  // ✨ ADD THIS: Track current playing song for stats
  String? _currentTrackingSongId;

  // State notifiers
  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);
  final ValueNotifier<Duration> position = ValueNotifier<Duration>(
    Duration.zero,
  );
  final ValueNotifier<Duration> duration = ValueNotifier<Duration>(
    Duration.zero,
  );
  final ValueNotifier<RepeatMode> repeatMode = ValueNotifier<RepeatMode>(
    RepeatMode.off,
  );
  final ValueNotifier<bool> isShuffleEnabled = ValueNotifier<bool>(false);
  final ValueNotifier<Song?> currentSong = ValueNotifier<Song?>(null);
  final ValueNotifier<int> currentIndex = ValueNotifier<int>(0);

  // Callbacks
  Function(Song song)? onSongChanged;
  VoidCallback? onQueueEnded;

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // Pause when headphones are unplugged or audio focus is lost
    session.becomingNoisyEventStream.listen((_) async {
      debugPrint('dY"ñ Audio focus: becoming noisy - pausing playback');
      await pause();
    });

    session.interruptionEventStream.listen((event) async {
      debugPrint('dY"ñ Audio focus interruption: ${event.type} (begin: ${event.begin})');
      if (event.begin) {
        await pause();
      }
    });

    await _copyDefaultArtwork();
    await _restorePlayerState();

    // Playing state
    _player.playingStream.listen((playing) async {
      isPlaying.value = playing;

      // ✨ ADD THIS: Handle pause/resume tracking
      if (!playing && _currentTrackingSongId != null) {
        // User paused - pause tracking
        await listeningStatsService.pauseListening();
        debugPrint('⏸️ Stats: Paused tracking');
      } else if (playing && _currentTrackingSongId != null) {
        // User resumed - resume tracking
        await listeningStatsService.resumeListening();
        debugPrint('▶️ Stats: Resumed tracking');
      }
    });

    // Position tracking
    _player.positionStream.listen((pos) {
      position.value = pos;
    });

    // Duration tracking
    _player.durationStream.listen((dur) {
      if (dur != null) {
        duration.value = dur;
      }
    });

    // Track index changes
    _player.currentIndexStream.listen((index) async {
      if (index == null || _currentQueue == null) return;

      debugPrint(
        '📍 Index changed to: \$index (manual: \$_isManualSeek, restoring: \$_isRestoringState)',
      );

      currentIndex.value = index;

      if (!_isManualSeek && !_isRestoringState) {
        debugPrint('🎵 Auto-advanced to index: \$index');
        await _handleSongChange(index);
      } else {
        _isManualSeek = false;
        if (!_isRestoringState) {
          await _handleSongChange(index);
        }
      }
    });

    // Auto-advance detection
    _player.positionDiscontinuityStream.listen((discontinuity) async {
      debugPrint('📊 Position discontinuity: \${discontinuity.reason}');

      if (discontinuity.reason == PositionDiscontinuityReason.autoAdvance) {
        final index = _player.currentIndex;
        if (index != null && _currentQueue != null && !_isRestoringState) {
          debugPrint('✅ Auto-advance confirmed to index: \$index');
          await _handleSongChange(index);
        }
      }
    });

    // Handle queue completion
    _player.processingStateStream.listen((state) async {
      debugPrint('📊 Processing state: \$state');

      if (state == ProcessingState.completed) {
        // ✨ ADD THIS: Stop tracking when song/queue completes
        if (_currentTrackingSongId != null) {
          await listeningStatsService.stopListening();
          _currentTrackingSongId = null;
          debugPrint('⏹️ Stats: Song completed, stopped tracking');
        }

        if (repeatMode.value == RepeatMode.off) {
          debugPrint('⏹️ Queue completed');
          isPlaying.value = false;
          onQueueEnded?.call();
        }
      }
    });

    // Handle player errors
    _player.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace st) async {
        debugPrint('❌ Player error: \$e');
        // ✨ ADD THIS: Stop tracking on error
        if (_currentTrackingSongId != null) {
          await listeningStatsService.stopListening();
          _currentTrackingSongId = null;
        }
      },
    );

    debugPrint('✅ AudioPlayerManager initialized');
  }

  Future<void> _restorePlayerState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final repeatValue = prefs.getString('repeat_mode');
      if (repeatValue != null) {
        try {
          repeatMode.value = RepeatMode.values.byName(repeatValue);
          await _player.setLoopMode(repeatMode.value.toLoopMode());
        } catch (e) {
          debugPrint('⚠️ Invalid repeat mode: \$repeatValue');
        }
      }

      final shuffleEnabled = prefs.getBool('shuffle_enabled') ?? false;
      isShuffleEnabled.value = shuffleEnabled;
      await _player.setShuffleModeEnabled(shuffleEnabled);

      debugPrint(
        '✅ Restored: repeat=\${repeatMode.value.name}, shuffle=\$shuffleEnabled',
      );
    } catch (e) {
      debugPrint('⚠️ Error restoring player state: \$e');
    }
  }

  Future<void> _savePlayerState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('repeat_mode', repeatMode.value.name);
      await prefs.setBool('shuffle_enabled', isShuffleEnabled.value);
      debugPrint('💾 Saved player state');
    } catch (e) {
      debugPrint('❌ Error saving player state: \$e');
    }
  }

  // ✨ MODIFIED: Handle song changes with stats tracking
  Future<void> _handleSongChange(int index) async {
    if (_currentQueue == null || index < 0 || index >= _currentQueue!.length) {
      debugPrint(
        '⚠️ Invalid index: \$index (queue length: \${_currentQueue?.length})',
      );
      return;
    }

    final newSong = _currentQueue![index];

    if (currentSong.value?.id != newSong.id) {
      // ✨ ADD THIS: Stop tracking previous song
      if (_currentTrackingSongId != null &&
          _currentTrackingSongId != newSong.id) {
        await listeningStatsService.stopListening();
        debugPrint('⏹️ Stats: Stopped tracking previous song');
      }

      currentSong.value = newSong;
      currentIndex.value = index;

      // ✨ ADD THIS: Start tracking new song (if playing)
      if (isPlaying.value && !_isRestoringState) {
        _currentTrackingSongId = newSong.id;
        await listeningStatsService.startListening(newSong.id);
        debugPrint('🎵 Stats: Started tracking \${newSong.title}');
      }

      debugPrint('✅ Song changed to: \${newSong.title} (index: \$index)');
      onSongChanged?.call(newSong);
    }
  }

  Future<void> _copyDefaultArtwork() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final artworkFile = File('${directory.path}/default_artwork.png');

      if (!artworkFile.existsSync()) {
        final ByteData data = await rootBundle.load(
          'assets/images/default_album_art.png',
        );
        final buffer = data.buffer.asUint8List();
        await artworkFile.writeAsBytes(buffer);
        debugPrint('✅ Default artwork copied');
      }

      _defaultArtworkPath = artworkFile.path;
    } catch (e) {
      debugPrint('❌ Failed to copy default artwork: \$e');
    }
  }

  Future<void> setSong(
    Song song, {
    List<Song>? queue,
    int? queueIndex,
    bool autoPlay = false,
    bool isRestoring = false,
  }) async {
    try {
      _isRestoringState = isRestoring;

      // ✨ ADD THIS: Stop tracking when setting new queue
      if (_currentTrackingSongId != null && !isRestoring) {
        await listeningStatsService.stopListening();
        _currentTrackingSongId = null;
        debugPrint('⏹️ Stats: Stopped tracking (setting new queue)');
      }

      final songsToPlay = queue ?? [song];
      final startIndex = queueIndex ?? 0;

      if (startIndex < 0 || startIndex >= songsToPlay.length) {
        debugPrint(
          '❌ Invalid start index: \$startIndex (queue: \${songsToPlay.length})',
        );
        _isRestoringState = false;
        return;
      }

      _currentQueue = songsToPlay;
      currentIndex.value = startIndex;
      currentSong.value = songsToPlay[startIndex];

      _currentPlaylist = ConcatenatingAudioSource(
        useLazyPreparation: true,
        shuffleOrder: DefaultShuffleOrder(),
        children: songsToPlay.map((s) => _createAudioSource(s)).toList(),
      );

      await _player.setAudioSource(
        _currentPlaylist!,
        initialIndex: startIndex,
        initialPosition: Duration.zero,
        preload: true,
      );

      debugPrint(
        '✅ Queue set: \${songsToPlay.length} songs at \$startIndex (autoPlay: \$autoPlay)',
      );

      if (autoPlay && !isRestoring) {
        await play();
      }

      _isRestoringState = false;
    } catch (e) {
      debugPrint('❌ Error setting audio source: \$e');
      _isRestoringState = false;
    }
  }

  AudioSource _createAudioSource(Song song) {
    final mediaItem = _createMediaItem(song);

    if (song.isLocalFile && song.filePath != null && song.filePath!.isNotEmpty) {
      // Support both content:// URIs (Android scoped storage) and absolute file paths.
      final parsed = Uri.tryParse(song.filePath!);
      if (parsed != null && parsed.scheme.isNotEmpty) {
        return AudioSource.uri(parsed, tag: mediaItem);
      }
      return AudioSource.file(song.filePath!, tag: mediaItem);
    } else if (song.audioAsset != null) {
      return AudioSource.asset(song.audioAsset!, tag: mediaItem);
    } else {
      throw Exception('Song has neither filePath nor audioAsset');
    }
  }

  MediaItem _createMediaItem(Song song) {
    Uri? artworkUri;

    if (song.albumArtPath != null && song.albumArtPath!.isNotEmpty) {
      try {
        artworkUri = Uri.file(song.albumArtPath!);
      } catch (e) {
        if (_defaultArtworkPath != null) {
          artworkUri = Uri.file(_defaultArtworkPath!);
        }
      }
    } else {
      if (_defaultArtworkPath != null) {
        artworkUri = Uri.file(_defaultArtworkPath!);
      }
    }

    return MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: song.duration,
      artUri: artworkUri,
      extras: <String, dynamic>{'filePath': song.filePath, 'songId': song.id},
    );
  }

  // ✨ MODIFIED: Start tracking when playing
  Future<void> play() async {
    try {
      if (_player.audioSource == null) {
        debugPrint('⚠️ No audio source to play');
        return;
      }

      await _player.play();

      // ✨ ADD THIS: Start tracking current song
      if (currentSong.value != null &&
          _currentTrackingSongId != currentSong.value!.id) {
        _currentTrackingSongId = currentSong.value!.id;
        await listeningStatsService.startListening(currentSong.value!.id);
        debugPrint('🎵 Stats: Started tracking \${currentSong.value!.title}');
      } else if (_currentTrackingSongId != null) {
        // Resuming same song
        await listeningStatsService.resumeListening();
        debugPrint('▶️ Stats: Resumed tracking');
      }

      debugPrint('▶️ Playing');
    } catch (e) {
      debugPrint('❌ Error on play: \$e');
    }
  }

  // ✨ MODIFIED: Pause tracking when pausing
  Future<void> pause() async {
    try {
      await _player.pause();

      // ✨ ADD THIS: Pause tracking
      if (_currentTrackingSongId != null) {
        await listeningStatsService.pauseListening();
        debugPrint('⏸️ Stats: Paused tracking');
      }

      debugPrint('⏸️ Paused');
    } catch (e) {
      debugPrint('❌ Error on pause: \$e');
    }
  }

  // ✨ MODIFIED: Stop tracking when stopping
  Future<void> stop() async {
    try {
      await _player.stop();

      // ✨ ADD THIS: Stop tracking
      if (_currentTrackingSongId != null) {
        await listeningStatsService.stopListening();
        _currentTrackingSongId = null;
        debugPrint('⏹️ Stats: Stopped tracking');
      }

      debugPrint('⏹️ Stopped');
    } catch (e) {
      debugPrint('❌ Error on stop: \$e');
    }
  }

  Future<void> seek(Duration newPosition) async {
    try {
      await _player.seek(newPosition);
    } catch (e) {
      debugPrint('❌ Error on seek: \$e');
    }
  }

  // ✨ MODIFIED: Handle tracking on skip
  Future<void> skipToNext() async {
    try {
      if (!_player.hasNext) {
        debugPrint('⚠️ No next song available');
        return;
      }

      // ✨ ADD THIS: Stop tracking current song before skip
      if (_currentTrackingSongId != null) {
        await listeningStatsService.stopListening();
        debugPrint('⏹️ Stats: Stopped tracking (skipping to next)');
      }

      _isManualSeek = true;
      await _player.seekToNext();

      await Future.delayed(const Duration(milliseconds: 100));

      final index = _player.currentIndex;
      if (index != null && _currentQueue != null) {
        await _handleSongChange(index);
      }

      debugPrint('⏭️ Skipped to next');
    } catch (e) {
      debugPrint('❌ Error skipping to next: \$e');
    }
  }

  // ✨ MODIFIED: Handle tracking on skip to previous
  Future<void> skipToPrevious() async {
    try {
      if (_player.position.inSeconds > 3) {
        await _player.seek(Duration.zero);
        debugPrint('🔄 Restarted current song');
        return;
      }

      if (!_player.hasPrevious) {
        debugPrint('⚠️ No previous song available');
        return;
      }

      // ✨ ADD THIS: Stop tracking current song before skip
      if (_currentTrackingSongId != null) {
        await listeningStatsService.stopListening();
        debugPrint('⏹️ Stats: Stopped tracking (skipping to previous)');
      }

      _isManualSeek = true;
      await _player.seekToPrevious();

      await Future.delayed(const Duration(milliseconds: 100));

      final index = _player.currentIndex;
      if (index != null && _currentQueue != null) {
        await _handleSongChange(index);
      }

      debugPrint('⏮️ Skipped to previous');
    } catch (e) {
      debugPrint('❌ Error skipping to previous: \$e');
    }
  }

  Future<void> toggleRepeatMode() async {
    final newMode = repeatMode.value.next;
    await setRepeatMode(newMode);
  }

  Future<void> setRepeatMode(RepeatMode mode) async {
    repeatMode.value = mode;
    try {
      await _player.setLoopMode(mode.toLoopMode());
      await _savePlayerState();
      debugPrint('🔁 Repeat mode: \${mode.label}');
    } catch (e) {
      debugPrint('❌ Error setting loop mode: \$e');
    }
  }

  Future<void> toggleShuffle() async {
    await setShuffleEnabled(!isShuffleEnabled.value);
  }

  Future<void> setShuffleEnabled(bool enabled) async {
    isShuffleEnabled.value = enabled;
    try {
      await _player.setShuffleModeEnabled(enabled);
      await _savePlayerState();
      debugPrint('🔀 Shuffle ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      debugPrint('❌ Error setting shuffle: \$e');
    }
  }

  List<Song>? get currentQueue => _currentQueue;
  Song? get getCurrentSong => currentSong.value;

  // ✨ MODIFIED: Clean up tracking on dispose
  Future<void> dispose() async {
    // ✨ ADD THIS: Stop tracking before disposing
    if (_currentTrackingSongId != null) {
      await listeningStatsService.stopListening();
      _currentTrackingSongId = null;
      debugPrint('⏹️ Stats: Stopped tracking (disposing)');
    }

    await _savePlayerState();
    await _player.stop();
    await _player.dispose();

    isPlaying.dispose();
    position.dispose();
    duration.dispose();
    repeatMode.dispose();
    isShuffleEnabled.dispose();
    currentSong.dispose();
    currentIndex.dispose();

    debugPrint('🧹 Audio player disposed');
  }
}
