import 'dart:io';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import 'package:audio_session/audio_session.dart';

import '../../../library/domain/entities/song.dart';
import '../../../library/data/playlist_repository.dart';
import '../../data/audio_player_manager.dart';
import '../../domain/repeat_mode.dart';
import '../widgets/album_artwork_section.dart';
import '../widgets/playback_controls.dart';
import '../widgets/progress_slider_section.dart';
import '../widgets/now_playing_actions_sheet.dart';
import '../../data/dynamic_color_service.dart';

class NowPlayingScreen extends StatefulWidget {
  final VoidCallback? onQueueTap;

  const NowPlayingScreen({super.key, this.onQueueTap});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _pageController;

  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  final AudioPlayerManager _player = AudioPlayerManager.instance;
  final PlaylistRepository _playlistRepo = PlaylistRepository.instance;

  double _verticalDragOffset = 0.0;
  double _horizontalDragOffset = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _slideAnimation = Tween<Offset>(
            begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _slideController, curve: Curves.easeOutCubic));

    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);

    _pageController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));

    _slideController.forward();
    _fadeController.forward();

    _checkFirstTimeGesture();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkFirstTimeGesture() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenGesture =
        prefs.getBool('has_seen_now_playing_gesture') ?? false;
    if (!hasSeenGesture && mounted) {
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) {
        _showGestureTutorial();
        await prefs.setBool('has_seen_now_playing_gesture', true);
      }
    }
  }

  void _showGestureTutorial() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: cs.surface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  cs.primary.withOpacity(0.2),
                  cs.secondary.withOpacity(0.2),
                ]),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.swipe_rounded, size: 56, color: cs.primary),
            ),
            const SizedBox(height: 24),
            Text(
              'Gesture Controls',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _GestureHint(
                icon: Icons.arrow_downward_rounded,
                text: 'Swipe down to close',
                colorScheme: cs),
            const SizedBox(height: 12),
            _GestureHint(
                icon: Icons.arrow_back_rounded,
                text: 'Swipe left for next song',
                colorScheme: cs),
            const SizedBox(height: 12),
            _GestureHint(
                icon: Icons.arrow_forward_rounded,
                text: 'Swipe right for previous',
                colorScheme: cs),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Got it!'),
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
      ),
    );
  }

  // ─── Manual Threshold Gesture Handling ────────────────────────────────────

  double _dragStartX = 0.0;
  double _dragStartY = 0.0;
  bool _dragAxisLocked = false;
  bool _isHorizontalDrag = false;

  void _handlePanDown(DragDownDetails details) {
    _dragStartX = details.globalPosition.dx;
    _dragStartY = details.globalPosition.dy;
    _dragAxisLocked = false;
    _isHorizontalDrag = false;
    _horizontalDragOffset = 0.0;
    _verticalDragOffset = 0.0;
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_dragAxisLocked) {
      final dx = details.globalPosition.dx - _dragStartX;
      final dy = details.globalPosition.dy - _dragStartY;

      // Wait until the user has dragged at least 15 logical pixels
      if (dx.abs() > 15 || dy.abs() > 15) {
        _dragAxisLocked = true;
        _isHorizontalDrag = dx.abs() > dy.abs();
        setState(() {
          _isDragging = true;
        });
      } else {
        // Still inside the 15px deadzone, do not move the UI yet.
        return;
      }
    }

    setState(() {
      if (_isHorizontalDrag) {
        _horizontalDragOffset += details.delta.dx;
        _horizontalDragOffset = _horizontalDragOffset.clamp(-200.0, 200.0);
      } else {
        _verticalDragOffset += details.delta.dy;
        // Only allow swiping downwards to dismiss
        _verticalDragOffset = _verticalDragOffset.clamp(0.0, 300.0);
      }
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!_dragAxisLocked) return; // Released before passing threshold

    if (_isHorizontalDrag) {
      if (_horizontalDragOffset < -80) {
        HapticFeedback.mediumImpact();
        _player.skipToNext();
        _animatePageTransition();
      } else if (_horizontalDragOffset > 80) {
        HapticFeedback.mediumImpact();
        _player.skipToPrevious();
        _animatePageTransition();
      } else {
        setState(() {
          _horizontalDragOffset = 0.0;
          _isDragging = false;
          _dragAxisLocked = false;
        });
      }
    } else {
      if (_verticalDragOffset > 120 || details.velocity.pixelsPerSecond.dy > 300) {
        HapticFeedback.lightImpact();
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _verticalDragOffset = 0.0;
        _isDragging = false;
        _dragAxisLocked = false;
      });
    }
  }

  void _handlePanCancel() {
    setState(() {
      _horizontalDragOffset = 0.0;
      _verticalDragOffset = 0.0;
      _isDragging = false;
      _dragAxisLocked = false;
      _isHorizontalDrag = false;
    });
  }

  void _animatePageTransition() {
    _pageController.forward(from: 0.0).then((_) {
      setState(() {
        _horizontalDragOffset = 0.0;
        _isDragging = false;
        _dragAxisLocked = false;
      });
    });
  }

  // ─── Actions ────────────────────────────────────────────────────────

  void _showActionsSheet(Song song) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => NowPlayingActionsSheet(song: song),
    );
  }

  void _handleFavoriteToggle(Song song, bool isFavorite) {
    HapticFeedback.mediumImpact();
    _playlistRepo.toggleFavorite(song.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isFavorite ? Icons.heart_broken : Icons.favorite,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(isFavorite
                ? 'Removed from Favorites'
                : 'Added to Favorites ❤️'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1500),
        backgroundColor: isFavorite
            ? Theme.of(context).colorScheme.surfaceVariant
            : Colors.red,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSleepTimerSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.timer_rounded, color: cs.primary, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Sleep Timer', 
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...[15, 30, 45, 60].map((mins) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.access_time_rounded,
                    color: cs.onSurface.withOpacity(0.8),
                  ),
                  title: Text(
                    '$mins minutes',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _player.setSleepTimer(Duration(minutes: mins));
                    Navigator.pop(ctx);
                  },
                )),
            ValueListenableBuilder<Duration?>(
              valueListenable: _player.sleepTimerRemaining,
              builder: (context, remaining, _) {
                if (remaining == null) return const SizedBox.shrink();
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.timer_off_rounded, color: cs.error),
                  title: Text(
                    'Turn off timer', 
                    style: TextStyle(
                      color: cs.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _player.cancelSleepTimer();
                    Navigator.pop(ctx);
                  },
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes > 0) {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '$seconds s';
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return ValueListenableBuilder<Song?>(
      valueListenable: _player.currentSong,
      builder: (context, currentSong, _) {
        if (currentSong == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_off_rounded,
                      size: 64, color: colorScheme.primary.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text(
                    'No song playing',
                    style: textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return PopScope(
          canPop: true,
          child: Scaffold(
            extendBodyBehindAppBar: true,
            backgroundColor: Colors.transparent,
            body: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanDown: _handlePanDown,
              onPanUpdate: _handlePanUpdate,
              onPanEnd: _handlePanEnd,
              onPanCancel: _handlePanCancel,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                transform: Matrix4.translationValues(
                  _horizontalDragOffset * 0.3,
                  _verticalDragOffset,
                  0,
                ),
                child: AnimatedOpacity(
                  opacity: _isDragging ? 0.8 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: _buildBody(
                        currentSong,
                        colorScheme,
                        textTheme,
                        isTablet,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    Song song,
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isTablet,
  ) {
    return ListenableBuilder(
      listenable: DynamicColorService.instance,
      builder: (context, _) {
        final double hPad = isTablet ? 48 : 24;
        
        // Use dynamically cached color
        final primaryColor = DynamicColorService.instance.dominantColor;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Stack(
          children: [
            // ── 1. Highly Optimized Dynamic Blurred Background ──
            if (song.albumArtPath != null && song.albumArtPath!.isNotEmpty && File(song.albumArtPath!).existsSync())
              Positioned.fill(
                // RepaintBoundary ensures the heavy blur is cached and not redrawn on every frame/animation
                child: RepaintBoundary(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Loading a tiny res version of the image saves massive memory and makes blurring cheaper
                      Image.file(
                        File(song.albumArtPath!),
                        fit: BoxFit.cover,
                        cacheWidth: 100, // Downscale internally to just 100px wide
                      ),
                      // The heavy blur filter
                      BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 50.0, sigmaY: 50.0),
                        child: Container(
                          // Dynamic tint to make texts/icons perfectly legible but still colorful
                          color: isDark 
                              ? Colors.black.withOpacity(0.75) // Darker for OLED
                              : primaryColor.withOpacity(0.15), // Light, colorful tint in light mode
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              // Fallback Gradient if no art
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isDark 
                        ? [
                            Color.lerp(Colors.black, primaryColor, 0.45)!,
                            Color.lerp(Colors.black, primaryColor, 0.15)!,
                            colorScheme.surface, 
                          ]
                        : [
                            Color.lerp(Colors.white, primaryColor, 0.25)!,
                            Color.lerp(Colors.white, primaryColor, 0.05)!,
                            colorScheme.surface, 
                          ],
                      stops: const [0.0, 0.45, 0.9],
                    ),
                  ),
                ),
              ),

            // ── 2. The Main Interactive UI ──
            Positioned.fill(
              child: SafeArea(
                child: Column(
              key: ValueKey(song.id),
              children: [
                // Top bar — only down arrow to match demo
                _TopBar(
                  colorScheme: colorScheme,
                  onClose: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop();
                  },
                ),

                const SizedBox(height: 8),

                // ── Artwork ──
                Flexible(
                  flex: 4, // Reduced flex to give controls more room
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad + 16), // Extra padding to scale art down slightly
                    child: AlbumArtworkSection(
                      song: song,
                      colorScheme: colorScheme,
                    ),
                  ),
                ),

                // Song Info, Actions, and Controls Area
                Flexible(
                  flex: 8, // Increased flex for airy, spacious layout
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // ── Like / Dislike + Menu row ──
                        _ArtworkActionsRow(
                          song: song,
                          colorScheme: colorScheme,
                          playlistRepo: _playlistRepo,
                          onFavoriteToggle: _handleFavoriteToggle,
                          onMenuTap: () => _showActionsSheet(song),
                        ),

                        // ── Song Title and Artist Pills ──
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark 
                                    ? Colors.white.withOpacity(0.08)
                                    : primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                song.title,
                                style: textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: colorScheme.onSurface,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.black.withOpacity(0.2)
                                    : primaryColor.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _buildSubtitle(song),
                                style: textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onSurface.withOpacity(0.7),
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _DeviceOutputIndicator(colorScheme: colorScheme, isDark: isDark),
                          ],
                        ),
                        
                        // ── Quick Actions Row ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _ActionChip(
                              icon: Icons.equalizer_rounded,
                              tooltip: 'Audio Quality',
                              onPressed: () => _showAudioStatsSheet(context, song),
                              colorScheme: colorScheme,
                            ),
                            const SizedBox(width: 12),
                            ValueListenableBuilder<Duration?>(
                              valueListenable: _player.sleepTimerRemaining,
                              builder: (context, remaining, _) {
                                final isActive = remaining != null;
                                return _ActionChip(
                                  icon: isActive ? Icons.timer_rounded : Icons.timer_outlined,
                                  isActive: isActive,
                                  tooltip: isActive 
                                      ? 'Sleep Timer: ${_formatDuration(remaining)}'
                                      : 'Sleep Timer',
                                  onPressed: () => _showSleepTimerSheet(context),
                                  colorScheme: colorScheme,
                                );
                              },
                            ),
                            
                            const SizedBox(width: 48), // Massive center gap matching demo
                            
                            ValueListenableBuilder<RepeatMode>(
                              valueListenable: _player.repeatMode,
                              builder: (context, mode, _) {
                                return _ActionChip(
                                  icon: mode == RepeatMode.one
                                      ? Icons.repeat_one_rounded
                                      : Icons.repeat_rounded,
                                  isActive: mode != RepeatMode.off,
                                  tooltip: 'Repeat',
                                  onPressed: _player.toggleRepeatMode,
                                  colorScheme: colorScheme,
                                );
                              },
                            ),
                            const SizedBox(width: 12),
                            ValueListenableBuilder<bool>(
                              valueListenable: _player.isShuffleEnabled,
                              builder: (context, isShuffle, _) {
                                return _ActionChip(
                                  icon: Icons.shuffle_rounded,
                                  isActive: isShuffle,
                                  tooltip: 'Shuffle',
                                  onPressed: _player.toggleShuffle,
                                  colorScheme: colorScheme,
                                );
                              },
                            ),
                          ],
                        ),

                        // ── Seek Bar & Playback Controls Overlay ──
                        // Layering the playback controls strictly over the interactive waveform
                        ProgressSliderSection(
                          player: _player,
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                          childControls: PlaybackControls(
                            player: _player,
                            onNext: () {
                              HapticFeedback.mediumImpact();
                              _player.skipToNext();
                            },
                            onPrevious: () {
                              HapticFeedback.mediumImpact();
                              _player.skipToPrevious();
                            },
                            colorScheme: colorScheme,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Floating Nav Bar at the very bottom
                _BottomNavBar(
                  colorScheme: colorScheme,
                  onQueue: widget.onQueueTap ?? () {},
                  onLyrics: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Lyrics integration coming soon!'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                  onPlaylist: () => _showActionsSheet(song),
                  onShare: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Sharing ${song.title}...'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  },
    );
  }

  String _buildSubtitle(Song song) {
    final artist = song.artist.isEmpty || song.artist == '<unknown>'
        ? 'Unknown Artist'
        : song.artist;
    final album = song.album.isEmpty || song.album == '<unknown>'
        ? 'Music'
        : song.album;
    return '$artist - $album';
  }

  void _showAudioStatsSheet(BuildContext context, Song song) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    
    // Extract format from file path, or default to MP3
    final format = song.filePath != null && song.filePath!.contains('.') 
        ? song.filePath!.split('.').last.toUpperCase() 
        : 'MP3';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.bar_chart_rounded, color: cs.primary, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Audio Quality', 
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _StatRow(label: 'Format', value: format, cs: cs),
            const SizedBox(height: 16),
            _StatRow(label: 'Sample Rate', value: '44.1 kHz', cs: cs),
            const SizedBox(height: 16),
            _StatRow(label: 'Bit Depth', value: '16 bit', cs: cs),
            const SizedBox(height: 16),
            _StatRow(label: 'Bitrate', value: '320 kbps', cs: cs),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Sensational'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _DeviceOutputIndicator extends StatefulWidget {
  final ColorScheme colorScheme;
  final bool isDark;

  const _DeviceOutputIndicator({required this.colorScheme, required this.isDark});

  @override
  State<_DeviceOutputIndicator> createState() => _DeviceOutputIndicatorState();
}

class _DeviceOutputIndicatorState extends State<_DeviceOutputIndicator> {
  String _deviceName = "Phone Speaker";
  IconData _deviceIcon = Icons.speaker_rounded;
  
  @override
  void initState() {
    super.initState();
    _initAudioSession();
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    _updateDevices(await session.getDevices());
    session.devicesStream.listen((devices) {
      if (mounted) _updateDevices(devices);
    });
  }

  void _updateDevices(Set<AudioDevice> devices) {
    // Filter to just outputs
    final outputs = devices.where((d) => d.isOutput).toList();
    if (outputs.isEmpty) return;

    // Check for Bluetooth first (highest priority usually)
    final btDevice = outputs.where((d) => 
      d.type == AudioDeviceType.bluetoothA2dp || 
      d.type == AudioDeviceType.bluetoothSco || 
      d.type == AudioDeviceType.bluetoothLe
    ).firstOrNull;

    if (btDevice != null) {
      setState(() {
        _deviceName = btDevice.name.isNotEmpty && btDevice.name != 'Unknown' 
            ? btDevice.name 
            : 'Bluetooth';
        _deviceIcon = Icons.bluetooth_audio_rounded;
      });
      return;
    }

    // Check for Wired Headphones / Headsets next
    final wiredDevice = outputs.where((d) => 
      d.type == AudioDeviceType.wiredHeadphones || 
      d.type == AudioDeviceType.wiredHeadset || 
      d.type == AudioDeviceType.usbAudio
    ).firstOrNull;

    if (wiredDevice != null) {
      setState(() {
        _deviceName = 'Headphones';
        _deviceIcon = Icons.headphones_rounded;
      });
      return;
    }

    // Fallback to internal speaker
    setState(() {
      _deviceName = 'Phone Speaker';
      _deviceIcon = Icons.speaker_rounded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(_deviceName),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: widget.isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _deviceIcon, 
              size: 14,
              color: widget.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _deviceName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: widget.colorScheme.primary,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme cs;

  const _StatRow({required this.label, required this.value, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label, 
          style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 16),
        ),
        Text(
          value, 
          style: TextStyle(
            color: cs.onSurface, 
            fontWeight: FontWeight.w700, 
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Top Bar
// ═══════════════════════════════════════════════════════════════════════════

class _TopBar extends StatelessWidget {
  final ColorScheme colorScheme;
  final VoidCallback onClose;

  const _TopBar({required this.colorScheme, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Minimal down button matching the demo
          IconButton(
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 32,
              color: colorScheme.onSurface.withOpacity(0.8),
            ),
            onPressed: onClose,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Actions row below artwork — thumbs up / thumbs down + 3-dot menu
// ═══════════════════════════════════════════════════════════════════════════

class _ArtworkActionsRow extends StatelessWidget {
  final Song song;
  final ColorScheme colorScheme;
  final PlaylistRepository playlistRepo;
  final void Function(Song, bool) onFavoriteToggle;
  final VoidCallback onMenuTap;

  const _ArtworkActionsRow({
    required this.song,
    required this.colorScheme,
    required this.playlistRepo,
    required this.onFavoriteToggle,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left — thumbs up + thumbs down in a single pill
        ValueListenableBuilder<Set<String>>(
          valueListenable: playlistRepo.favoriteSongIds,
          builder: (context, favorites, _) {
            final isFav = favorites.contains(song.id);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.12) : colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SmallIconButton(
                    icon: isFav ? Icons.thumb_up_alt : Icons.thumb_up_off_alt,
                    isActive: isFav,
                    activeColor: isDark ? Colors.white : colorScheme.primary,
                    inactiveColor: isDark ? Colors.white70 : colorScheme.onSurface.withOpacity(0.6),
                    onPressed: () => onFavoriteToggle(song, isFav),
                  ),
                  const SizedBox(width: 16),
                  _SmallIconButton(
                    icon: Icons.thumb_down_off_alt,
                    isActive: false,
                    activeColor: isDark ? Colors.white : colorScheme.primary,
                    inactiveColor: isDark ? Colors.white70 : colorScheme.onSurface.withOpacity(0.6),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              const Text('Noted! We\'ll play less like this'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 1),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),

        // Right — 3-dot overflow in a circle
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.12) : colorScheme.primary.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: _SmallIconButton(
            icon: Icons.more_vert_rounded,
            isActive: false,
            activeColor: isDark ? Colors.white : colorScheme.primary,
            inactiveColor: isDark ? Colors.white70 : colorScheme.onSurface.withOpacity(0.6),
            onPressed: onMenuTap,
          ),
        ),
      ],
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onPressed;

  const _SmallIconButton({
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, anim) =>
            ScaleTransition(scale: anim, child: child),
        child: Icon(
          icon,
          key: ValueKey('$icon-$isActive'),
          size: 22,
          color: isActive ? activeColor : inactiveColor,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════

class _ActionChip extends StatefulWidget {
  final IconData icon;
  final String? tooltip;
  final bool isActive;
  final VoidCallback? onPressed;
  final ColorScheme colorScheme;

  const _ActionChip({
    required this.icon,
    this.tooltip,
    this.isActive = false,
    required this.onPressed,
    required this.colorScheme,
  });

  @override
  State<_ActionChip> createState() => _ActionChipState();
}

class _ActionChipState extends State<_ActionChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _tap;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _tap = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 80));
    _scale = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _tap, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = 44.0;
    const iconSize = 22.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final child = AnimatedBuilder(
      animation: _scale,
      builder: (context, _) {
        return Transform.scale(
          scale: _scale.value,
          child: GestureDetector(
            onTapDown: (_) => _tap.forward(),
            onTapUp: (_) {
              _tap.reverse();
              widget.onPressed?.call();
            },
            onTapCancel: () => _tap.reverse(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isActive
                    ? (isDark ? Colors.white.withOpacity(0.3) : widget.colorScheme.primary.withOpacity(0.15))
                    : (isDark ? Colors.white.withOpacity(0.12) : widget.colorScheme.onSurface.withOpacity(0.08)),
                border: widget.isActive
                    ? Border.all(
                        color: isDark ? Colors.white : widget.colorScheme.primary,
                        width: 1.5,
                      )
                    : Border.all(color: Colors.transparent, width: 0),
              ),
              child: Icon(
                widget.icon,
                size: iconSize,
                color: isDark 
                    ? Colors.white 
                    : (widget.isActive ? widget.colorScheme.primary : widget.colorScheme.onSurface),
              ),
            ),
          ),
        );
      },
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: child);
    }
    return child;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Bottom Nav Bar Mock
// ═══════════════════════════════════════════════════════════════════════════

class _BottomNavBar extends StatelessWidget {
  final ColorScheme colorScheme;
  final VoidCallback onQueue;
  final VoidCallback onLyrics;
  final VoidCallback onPlaylist;
  final VoidCallback onShare;

  const _BottomNavBar({
    required this.colorScheme,
    required this.onQueue,
    required this.onLyrics,
    required this.onPlaylist,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    // Dynamic background matching the surface color for perfect Light/Dark mode integration
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface, 
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          if (isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          else
            BoxShadow(
              color: colorScheme.shadow.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavIcon(
            icon: Icons.queue_music_rounded,
            isActive: true, // Queue is the primary contextual view from here
            colorScheme: colorScheme,
            onPressed: onQueue,
          ),
          _NavIcon(
            icon: Icons.lyrics_rounded,
            isActive: false,
            colorScheme: colorScheme,
            onPressed: onLyrics,
          ),
          _NavIcon(
            icon: Icons.playlist_add_rounded,
            isActive: false,
            colorScheme: colorScheme,
            onPressed: onPlaylist,
          ),
          _NavIcon(
            icon: Icons.share_rounded,
            isActive: false,
            colorScheme: colorScheme,
            onPressed: onShare,
          ),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final ColorScheme colorScheme;
  final VoidCallback onPressed;

  const _NavIcon({
    required this.icon,
    required this.isActive,
    required this.colorScheme,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? colorScheme.primary.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          icon,
          size: 26,
          color: isActive
              ? colorScheme.primary
              : colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Tutorial Helper Widget
// ═══════════════════════════════════════════════════════════════════════════

class _GestureHint extends StatelessWidget {
  final IconData icon;
  final String text;
  final ColorScheme colorScheme;

  const _GestureHint({
    required this.icon,
    required this.text,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
        ),
      ],
    );
  }
}
