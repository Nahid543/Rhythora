import 'dart:async';
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
import '../../../core/services/battery_saver_service.dart';

class AudioPlayerManager {
  AudioPlayerManager._internal() {
    _init();
  }

  static final AudioPlayerManager instance = AudioPlayerManager._internal();
  final Completer<void> _initCompleter = Completer<void>();

  final AudioPlayer _player = AudioPlayer();

  ConcatenatingAudioSource? _currentPlaylist;
  List<Song>? _currentQueue;
  String? _defaultArtworkPath;
  bool _isManualSeek = false;
  bool _isRestoringState = false;

  String? _currentTrackingSongId;

  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);
  final ValueNotifier<Duration> position =
      ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> duration =
      ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<RepeatMode> repeatMode =
      ValueNotifier<RepeatMode>(RepeatMode.off);
  final ValueNotifier<bool> isShuffleEnabled =
      ValueNotifier<bool>(false);
  final ValueNotifier<Song?> currentSong =
      ValueNotifier<Song?>(null);
  final ValueNotifier<int> currentIndex = ValueNotifier<int>(0);

  Function(Song song)? onSongChanged;
  VoidCallback? onQueueEnded;

  Future<void> _init() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      session.becomingNoisyEventStream.listen((_) async {
        debugPrint('[AudioPlayer] Becoming noisy - pausing playback');
        await pause();
      });

      session.interruptionEventStream.listen((event) async {
        debugPrint(
          '[AudioPlayer] Interruption: ${event.type} (begin: ${event.begin})',
        );
        if (event.begin) {
          await pause();
        }
      });

      await _copyDefaultArtwork();
      await _restorePlayerState();

      _player.playingStream.listen((playing) async {
        isPlaying.value = playing;

        if (!playing && _currentTrackingSongId != null) {
          await listeningStatsService.pauseListening();
          debugPrint('[Stats] Paused tracking');
        } else if (playing && _currentTrackingSongId != null) {
          await listeningStatsService.resumeListening();
          debugPrint('[Stats] Resumed tracking');
        }
      });

      _player.positionStream.listen((pos) {
        position.value = pos;
      });

      _player.durationStream.listen((dur) {
        duration.value = dur ?? Duration.zero;
      });

      _player.currentIndexStream.listen((index) async {
        if (index == null || _currentQueue == null) return;

        debugPrint(
          '[AudioPlayer] Index changed to: $index (manual: $_isManualSeek, restoring: $_isRestoringState)',
        );

        currentIndex.value = index;

        if (!_isManualSeek && !_isRestoringState) {
          debugPrint('[AudioPlayer] Auto advanced to index: $index');
          await _handleSongChange(index);
        } else {
          _isManualSeek = false;
          if (!_isRestoringState) {
            await _handleSongChange(index);
          }
        }
      });

      _player.positionDiscontinuityStream.listen((discontinuity) async {
        debugPrint(
          '[AudioPlayer] Position discontinuity: ${discontinuity.reason}',
        );

        if (discontinuity.reason ==
            PositionDiscontinuityReason.autoAdvance) {
          final index = _player.currentIndex;
          if (index != null &&
              _currentQueue != null &&
              !_isRestoringState) {
            debugPrint('[AudioPlayer] Auto-advance confirmed: $index');
            await _handleSongChange(index);
          }
        }
      });

      // ✅ FIXED: Queue completion - PAUSE on last song, KEEP currentSong visible
      _player.processingStateStream.listen((state) async {
        debugPrint('[AudioPlayer] Processing state: $state');

        if (state == ProcessingState.completed) {
          // Stop stats tracking for completed song
          if (_currentTrackingSongId != null) {
            await listeningStatsService.stopListening();
            _currentTrackingSongId = null;
            debugPrint('[Stats] Song completed, stopped tracking');
          }

          if (repeatMode.value == RepeatMode.off) {
            debugPrint('[AudioPlayer] Queue completed (no repeat) - pausing on last song');
            
            // ✅ FIX 1: Just pause - DON'T clear currentSong/queue for miniplayer
            await _player.pause();  // playingStream handles isPlaying.value = false
            
            // ✅ FIX 2: Reset UI state for clean paused appearance
            duration.value = Duration.zero;
            position.value = Duration.zero;
            
            onQueueEnded?.call();
          }
        }
      });

      _player.playbackEventStream.listen(
        (event) {},
        onError: (Object e, StackTrace st) async {
          debugPrint('[AudioPlayer] Playback error: $e');
          if (_currentTrackingSongId != null) {
            await listeningStatsService.stopListening();
            _currentTrackingSongId = null;
          }
        },
      );

      debugPrint('[AudioPlayer] Initialized');
    } finally {
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    }
  }

  Future<void> _ensureInitialized() => _initCompleter.future;

  Future<void> _restorePlayerState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final repeatValue = prefs.getString('repeat_mode');
      if (repeatValue != null) {
        try {
          repeatMode.value = RepeatMode.values.byName(repeatValue);
          await _player.setLoopMode(repeatMode.value.toLoopMode());
        } catch (e) {
          debugPrint('⚠️ Invalid repeat mode: $repeatValue');
        }
      }

      final shuffleEnabled = prefs.getBool('shuffle_enabled') ?? false;
      isShuffleEnabled.value = shuffleEnabled;
      await _player.setShuffleModeEnabled(shuffleEnabled);

      debugPrint(
        '✅ Restored: repeat=${repeatMode.value.name}, shuffle=$shuffleEnabled',
      );
    } catch (e) {
      debugPrint('⚠️ Error restoring player state: $e');
    }
  }

  Future<void> _savePlayerState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('repeat_mode', repeatMode.value.name);
      await prefs.setBool('shuffle_enabled', isShuffleEnabled.value);
      debugPrint('Saved player state');
    } catch (e) {
      debugPrint('❌ Error saving player state: $e');
    }
  }

  Future<void> _handleSongChange(int index) async {
    if (_currentQueue == null ||
        index < 0 ||
        index >= _currentQueue!.length) {
      debugPrint(
        '⚠️ Invalid index: $index (queue length: ${_currentQueue?.length})',
      );
      return;
    }

    final newSong = _currentQueue![index];

    if (currentSong.value?.id != newSong.id) {
      if (_currentTrackingSongId != null &&
          _currentTrackingSongId != newSong.id) {
        await listeningStatsService.stopListening();
        debugPrint('⏹️ Stats: Stopped tracking previous song');
      }

      currentSong.value = newSong;
      currentIndex.value = index;

      if (isPlaying.value && !_isRestoringState) {
        _currentTrackingSongId = newSong.id;
        await listeningStatsService.startListening(newSong.id);
        debugPrint('🎵 Stats: Started tracking ${newSong.title}');
      }

      debugPrint(
        '✅ Song changed to: ${newSong.title} (index: $index)',
      );
      onSongChanged?.call(newSong);
    }
  }

  Future<void> _copyDefaultArtwork() async {
    try {
      if (_defaultArtworkPath != null) {
        final cachedFile = File(_defaultArtworkPath!);
        if (cachedFile.existsSync()) return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final artworkFile =
          File('${directory.path}/default_artwork.png');

      if (!artworkFile.existsSync()) {
        final ByteData data = await rootBundle.load(
          'assets/images/default_album_art.png',
        );
        final buffer = data.buffer.asUint8List();
        await artworkFile.writeAsBytes(buffer);
        debugPrint('[AudioPlayer] Default artwork copied');
      }

      _defaultArtworkPath = artworkFile.path;
    } catch (e) {
      debugPrint('[AudioPlayer] Failed to copy default artwork: $e');
    }
  }

  Uri? _resolveArtworkUri(Song song) {
    if (!BatterySaverService.instance.shouldLoadAlbumArt) {
      if (_defaultArtworkPath != null &&
          _defaultArtworkPath!.isNotEmpty) {
        return Uri.file(_defaultArtworkPath!);
      }
      return null;
    }

    final artPath = song.albumArtPath;
    if (artPath != null && artPath.isNotEmpty) {
      final parsed = Uri.tryParse(artPath);
      if (parsed != null) {
        if (parsed.scheme.isEmpty || parsed.scheme == 'file') {
          return Uri.file(artPath);
        }
        return parsed;
      }
      return Uri.file(artPath);
    }

    if (_defaultArtworkPath != null &&
        _defaultArtworkPath!.isNotEmpty) {
      return Uri.file(_defaultArtworkPath!);
    }

    return null;
  }

  Future<void> setSong(
    Song song, {
    List<Song>? queue,
    int? queueIndex,
    bool autoPlay = false,
    bool isRestoring = false,
  }) async {
    try {
      await _ensureInitialized();
      _isRestoringState = isRestoring;

      if (_currentTrackingSongId != null && !isRestoring) {
        await listeningStatsService.stopListening();
        _currentTrackingSongId = null;
        debugPrint('⏹️ Stats: Stopped tracking (setting new queue)');
      }

      final songsToPlay = queue ?? [song];
      final startIndex = queueIndex ?? 0;

      if (startIndex < 0 || startIndex >= songsToPlay.length) {
        debugPrint(
          '❌ Invalid start index: $startIndex (queue: ${songsToPlay.length})',
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
        children:
            songsToPlay.map((s) => _createAudioSource(s)).toList(),
      );

      await _player.setAudioSource(
        _currentPlaylist!,
        initialIndex: startIndex,
        initialPosition: Duration.zero,
        preload: BatterySaverService.instance.shouldLoadAlbumArt,
      );

      debugPrint(
        '✅ Queue set: ${songsToPlay.length} songs at $startIndex (autoPlay: $autoPlay)',
      );

      if (autoPlay && !isRestoring) {
        await play();
      }

      _isRestoringState = false;
    } catch (e) {
      debugPrint('❌ Error setting audio source: $e');
      _isRestoringState = false;
    }
  }

  AudioSource _createAudioSource(Song song) {
    final mediaItem = _createMediaItem(song);

    if (song.isLocalFile &&
        song.filePath != null &&
        song.filePath!.isNotEmpty) {
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
    final artworkUri = _resolveArtworkUri(song);
    return MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: song.duration,
      artUri: artworkUri,
      extras: <String, dynamic>{
        'filePath': song.filePath,
        'songId': song.id,
      },
    );
  }

  Future<void> play() async {
    try {
      await _ensureInitialized();
      if (_player.audioSource == null) {
        debugPrint('⚠️ No audio source to play');
        return;
      }

      await _player.play();

      if (currentSong.value != null &&
          _currentTrackingSongId != currentSong.value!.id) {
        _currentTrackingSongId = currentSong.value!.id;
        await listeningStatsService.startListening(
          currentSong.value!.id,
        );
        debugPrint(
          '🎵 Stats: Started tracking ${currentSong.value!.title}',
        );
      } else if (_currentTrackingSongId != null) {
        await listeningStatsService.resumeListening();
        debugPrint('▶️ Stats: Resumed tracking');
      }

      debugPrint('▶️ Playing');
    } catch (e) {
      debugPrint('❌ Error on play: $e');
    }
  }

  Future<void> pause() async {
    try {
      await _ensureInitialized();
      await _player.pause();

      if (_currentTrackingSongId != null) {
        await listeningStatsService.pauseListening();
        debugPrint('⏸️ Stats: Paused tracking');
      }

      debugPrint('⏸️ Paused');
    } catch (e) {
      debugPrint('❌ Error on pause: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _ensureInitialized();
      await _player.stop();

      if (_currentTrackingSongId != null) {
        await listeningStatsService.stopListening();
        _currentTrackingSongId = null;
        debugPrint('⏹️ Stats: Stopped tracking');
      }

      debugPrint('⏹️ Stopped');
    } catch (e) {
      debugPrint('❌ Error on stop: $e');
    }
  }

  Future<void> seek(Duration newPosition) async {
    try {
      await _ensureInitialized();
      await _player.seek(newPosition);
    } catch (e) {
      debugPrint('❌ Error on seek: $e');
    }
  }

  Future<void> skipToNext() async {
    try {
      await _ensureInitialized();
      if (!_player.hasNext) {
        debugPrint('⚠️ No next song available');
        return;
      }

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
      debugPrint('❌ Error skipping to next: $e');
    }
  }

  Future<void> skipToPrevious() async {
    try {
      await _ensureInitialized();
      if (_player.position.inSeconds > 3) {
        await _player.seek(Duration.zero);
        debugPrint('🔄 Restarted current song');
        return;
      }

      if (!_player.hasPrevious) {
        debugPrint('⚠️ No previous song available');
        return;
      }

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
      debugPrint('❌ Error skipping to previous: $e');
    }
  }

  Future<void> toggleRepeatMode() async {
    final newMode = repeatMode.value.next;
    await setRepeatMode(newMode);
  }

  Future<void> setRepeatMode(RepeatMode mode) async {
    repeatMode.value = mode;
    try {
      await _ensureInitialized();
      await _player.setLoopMode(mode.toLoopMode());
      await _savePlayerState();
      debugPrint('🔁 Repeat mode: ${mode.label}');
    } catch (e) {
      debugPrint('❌ Error setting loop mode: $e');
    }
  }

  Future<void> toggleShuffle() async {
    await setShuffleEnabled(!isShuffleEnabled.value);
  }

  Future<void> setShuffleEnabled(bool enabled) async {
    isShuffleEnabled.value = enabled;
    try {
      await _ensureInitialized();
      await _player.setShuffleModeEnabled(enabled);
      await _savePlayerState();
      debugPrint(
        '🔀 Shuffle ${enabled ? 'enabled' : 'disabled'}',
      );
    } catch (e) {
      debugPrint('❌ Error setting shuffle: $e');
    }
  }

  List<Song>? get currentQueue => _currentQueue;
  Song? get getCurrentSong => currentSong.value;

  Future<void> dispose() async {
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
