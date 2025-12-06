// lib/src/app/root_shell.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// ignore: unused_import
import '../core/theme/app_colors.dart';
import '../core/widgets/animated_nav_bar.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/library/presentation/screens/library_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/library/domain/entities/song.dart';
import '../features/playback/presentation/screens/now_playing_screen.dart';
import '../features/playback/presentation/widgets/mini_player_bar.dart';
import '../features/playback/presentation/widgets/queue_sheet.dart'; 
import '../features/playback/data/audio_player_manager.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> with WidgetsBindingObserver {
  int _currentIndex = 0;

  List<Song> _queue = const [];
  int _currentSongIndex = -1;

  List<int> _shuffledIndices = [];
  List<Song> _recentlyPlayed = [];
  List<Song> _allLibrarySongs = [];

  DateTime? _lastBackPress;
  bool _wasPlayingBeforeBackground = false;

  final AudioPlayerManager _player = AudioPlayerManager.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Listen for song changes to update recent
    _player.currentSong.addListener(_onPlayerSongChanged);

    _loadPersistedState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _player.currentSong.removeListener(_onPlayerSongChanged);
    super.dispose();
  }

  void _onPlayerSongChanged() {
    final song = _player.currentSong.value;
    if (song != null) {
      _addToRecentlyPlayed(song);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
        debugPrint('📱 App paused');
        _wasPlayingBeforeBackground = _player.isPlaying.value;
        _saveState();
        break;

      case AppLifecycleState.resumed:
        debugPrint('📱 App resumed (was playing: $_wasPlayingBeforeBackground)');
        break;

      case AppLifecycleState.inactive:
        debugPrint('📱 App inactive');
        break;

      case AppLifecycleState.detached:
        debugPrint('📱 App detached - saving (playback keeps running)');
        _saveState();
        break;

      case AppLifecycleState.hidden:
        debugPrint('📱 App hidden');
        break;
    }
  }

  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final currentSong = _player.currentSong.value;
      if (currentSong != null) {
        await prefs.setString(
          'current_song',
          jsonEncode(currentSong.toJson()),
        );
        await prefs.setInt('current_song_index', _currentSongIndex);
      }

      if (_queue.isNotEmpty) {
        final queueJson = _queue.map((s) => s.toJson()).toList();
        await prefs.setString('queue', jsonEncode(queueJson));
      }

      if (_recentlyPlayed.isNotEmpty) {
        final recentJson = _recentlyPlayed.map((s) => s.toJson()).toList();
        await prefs.setString('recently_played', jsonEncode(recentJson));
      } else {
        await prefs.remove('recently_played');
      }

      final position = _player.position.value;
      await prefs.setInt('playback_position', position.inMilliseconds);
      await prefs.setBool('was_playing', _player.isPlaying.value);

      debugPrint('💾 State saved');
    } catch (e) {
      debugPrint('❌ Error saving state: $e');
    }
  }

  Future<void> _loadPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load recently played
      final recentJson = prefs.getString('recently_played');
      if (recentJson != null) {
        final List<dynamic> decoded = jsonDecode(recentJson);
        setState(() {
          _recentlyPlayed = decoded.map((json) => Song.fromJson(json)).toList();
        });
        debugPrint('✅ Loaded ${_recentlyPlayed.length} recently played');
      }

      // Load song and queue
      final songJson = prefs.getString('current_song');
      final queueJson = prefs.getString('queue');
      final songIndex = prefs.getInt('current_song_index') ?? -1;

      if (songJson != null && queueJson != null) {
        final song = Song.fromJson(jsonDecode(songJson));
        final List<dynamic> decodedQueue = jsonDecode(queueJson);
        final queue = decodedQueue.map((json) => Song.fromJson(json)).toList();

        if (songIndex < 0 || songIndex >= queue.length) {
          debugPrint('⚠️ Invalid persisted index: $songIndex (queue: ${queue.length})');
          return;
        }

        setState(() {
          _queue = queue;
          _currentSongIndex = songIndex;
        });

        await _player.setSong(
          song,
          queue: queue,
          queueIndex: songIndex,
          autoPlay: false,
          isRestoring: true,
        );

        // Restore position
        final position = prefs.getInt('playback_position') ?? 0;
        if (position > 0) {
          await _player.seek(Duration(milliseconds: position));
        }

        debugPrint('✅ State restored: ${song.title} (PAUSED at ${position}ms)');
      }
    } catch (e) {
      debugPrint('❌ Error loading state: $e');
    }
  }

  void _handleSongsLoaded(List<Song> songs) {
    setState(() {
      _allLibrarySongs = songs;
    });
    debugPrint('📚 Loaded ${songs.length} songs from library');
  }

  void _addToRecentlyPlayed(Song song) {
    setState(() {
      _recentlyPlayed.removeWhere((s) => s.id == song.id);
      _recentlyPlayed.insert(0, song);
      if (_recentlyPlayed.length > 20) {
        _recentlyPlayed = _recentlyPlayed.sublist(0, 20);
      }
    });
  }

  void _playSong(Song song, List<Song> queue, int index) {
    if (index < 0 || index >= queue.length) {
      debugPrint('❌ Invalid index: $index (queue: ${queue.length})');
      return;
    }

    setState(() {
      _queue = queue;
      _currentSongIndex = index;
      _shuffledIndices = [];
    });

    debugPrint('▶️ Playing: ${song.title} (index: $index)');

    _player.setSong(
      song,
      queue: queue,
      queueIndex: index,
      autoPlay: true,
      isRestoring: false,
    );
  }

  void _handleRecentlyPlayedSelected(Song song) {
    final indexInQueue = _queue.indexWhere((s) => s.id == song.id);

    if (indexInQueue != -1) {
      _playSong(song, _queue, indexInQueue);
    } else {
      final useFullLibrary = _allLibrarySongs.isNotEmpty;
      final newQueue = useFullLibrary ? _allLibrarySongs : [song];
      final songIndex = useFullLibrary
          ? newQueue.indexWhere((s) => s.id == song.id)
          : 0;

      _playSong(song, newQueue, songIndex >= 0 ? songIndex : 0);
    }

    _openNowPlaying();
  }

  void _handleSongSelected(Song song, List<Song> allSongs, int index) {
    if (index < 0 || index >= allSongs.length) {
      debugPrint('⚠️ Invalid song index: $index');
      return;
    }

    _playSong(song, allSongs, index);
    _openNowPlaying();
  }

  void _openNowPlaying() {
    if (_player.currentSong.value == null) {
      debugPrint('⚠️ No current song to display');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NowPlayingScreen(
          onQueueTap: _openQueueSheet,
        ),
      ),
    );
  }

  void _openQueueSheet() {
    if (_queue.isEmpty) {
      debugPrint('⚠️ Queue is empty');
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: QueueSheet(
          queue: _queue,
          onSongTap: (song, index) => _playSong(song, _queue, index),
        ),
      ),
    );
  }

  void _handleRemoveFromRecent(Song song) {
    setState(() {
      _recentlyPlayed.removeWhere((s) => s.id == song.id);
    });
    _saveState();
  }

  void _clearRecentlyPlayed() {
    setState(() {
      _recentlyPlayed.clear();
    });
    _saveState();
  }

  Future<bool> _onWillPop() async {
    if (_currentIndex != 0) {
      setState(() {
        _currentIndex = 0;
      });
      return false;
    }

    final now = DateTime.now();
    final backButtonHasNotBeenPressedOrSnackBarHasBeenClosed =
        _lastBackPress == null ||
            now.difference(_lastBackPress!) > const Duration(seconds: 2);

    if (backButtonHasNotBeenPressedOrSnackBarHasBeenClosed) {
      _lastBackPress = now;

      if (mounted) {
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: colorScheme.onInverseSurface,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Press back again to minimize',
                  style: TextStyle(color: colorScheme.onInverseSurface),
                ),
              ],
            ),
            backgroundColor: colorScheme.inverseSurface,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }

      return false;
    }

    await _saveState();
    return true;
  }

  Widget _buildCurrentTab() {
    switch (_currentIndex) {
      case 0:
        return HomeScreen(
          currentSong: _player.currentSong.value,
          recentlyPlayed: _recentlyPlayed,
          onOpenNowPlaying: _openNowPlaying,
          onOpenLibrary: () {
            setState(() {
              _currentIndex = 1;
            });
          },
          onOpenQueue: _openQueueSheet,
          onRecentlyPlayedTap: _handleRecentlyPlayedSelected,
          onRemoveFromRecent: _handleRemoveFromRecent,
          onClearRecentlyPlayed: _clearRecentlyPlayed,
          allSongs: _allLibrarySongs.isNotEmpty ? _allLibrarySongs : _queue,
          onSongSelected: _handleSongSelected,
        );
      case 1:
        return LibraryScreen(
          onSongSelected: _handleSongSelected,
          onSongsLoaded: _handleSongsLoaded,
        );
      case 2:
      default:
        return const SettingsScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && mounted) {
            await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
          }
        }
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(child: _buildCurrentTab()),
              MiniPlayerBar(onTap: _openNowPlaying),
            ],
          ),
        ),
        bottomNavigationBar: AnimatedNavBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          colorScheme: colorScheme,
        ),
      ),
    );
  }
}
