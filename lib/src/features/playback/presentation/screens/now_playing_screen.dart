import 'dart:io';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';

import '../../../library/domain/entities/song.dart';
import '../../../library/data/playlist_repository.dart';
import '../../data/audio_player_manager.dart';
import '../../domain/repeat_mode.dart';
import '../widgets/album_artwork_section.dart';
import '../widgets/playback_controls.dart';
import '../widgets/progress_slider_section.dart';
import '../widgets/now_playing_actions_sheet.dart';

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
  bool _isHorizontalDrag = false;

  ColorScheme? _dynamicColorScheme;

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

    _player.currentSong.addListener(_updateDynamicColor);
    _updateDynamicColor();
  }

  Future<void> _updateDynamicColor() async {
    final song = _player.currentSong.value;
    if (song != null && song.albumArtPath != null && song.albumArtPath!.isNotEmpty) {
      try {
        final provider = FileImage(File(song.albumArtPath!));
        final newScheme = await ColorScheme.fromImageProvider(
          provider: provider,
          brightness: Theme.of(context).brightness,
        );
        if (mounted) {
          setState(() {
            _dynamicColorScheme = newScheme;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _dynamicColorScheme = null);
      }
    } else {
      if (mounted) setState(() => _dynamicColorScheme = null);
    }
  }

  @override
  void dispose() {
    _player.currentSong.removeListener(_updateDynamicColor);
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

  // ─── Gesture handling ───────────────────────────────────────────────

  void _handlePanUpdate(DragUpdateDetails details) {
    setState(() {
      _isDragging = true;
      if (!_isHorizontalDrag && _verticalDragOffset.abs() < 10) {
        if (details.delta.dx.abs() > details.delta.dy.abs()) {
          _isHorizontalDrag = true;
        }
      }
      if (_isHorizontalDrag) {
        _horizontalDragOffset += details.delta.dx;
        _horizontalDragOffset = _horizontalDragOffset.clamp(-200.0, 200.0);
      } else {
        _verticalDragOffset += details.delta.dy;
        _verticalDragOffset = _verticalDragOffset.clamp(0.0, 300.0);
      }
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_isHorizontalDrag) {
      if (_horizontalDragOffset < -80) {
        HapticFeedback.mediumImpact();
        _player.skipToNext();
        _animatePageTransition();
      } else if (_horizontalDragOffset > 80) {
        HapticFeedback.mediumImpact();
        _player.skipToPrevious();
        _animatePageTransition();
      }
    } else {
      if (_verticalDragOffset > 120) {
        HapticFeedback.lightImpact();
        Navigator.of(context).pop();
        return;
      }
    }
    setState(() {
      _horizontalDragOffset = 0.0;
      _verticalDragOffset = 0.0;
      _isDragging = false;
      _isHorizontalDrag = false;
    });
  }

  void _animatePageTransition() {
    _pageController.forward(from: 0.0).then((_) {
      setState(() {
        _horizontalDragOffset = 0.0;
        _isDragging = false;
        _isHorizontalDrag = false;
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
              onPanUpdate: _handlePanUpdate,
              onPanEnd: _handlePanEnd,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final double hPad = isTablet ? 48 : 24;
        
        // Use dynamic color or fallback to theme
        final primaryColor = _dynamicColorScheme?.primary ?? colorScheme.primary;

        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                // Top: Strongly tinted by the artwork, but still fairly dark
                Color.lerp(Colors.black, primaryColor, 0.45)!,
                // Middle: Fading quickly to pitch black
                Color.lerp(Colors.black, primaryColor, 0.15)!,
                // Bottom: Deep black background
                const Color(0xFF0F0F1A), // Matching bottom nav bar
              ],
              stops: const [0.0, 0.45, 0.9],
            ),
          ),
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

                        // ── Song title & Artist ──
                        SizedBox(
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Text(
                                  song.title,
                                  style: textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                    height: 1.2,
                                    fontSize: isTablet ? 24 : 20,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.left,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Text(
                                  _buildSubtitle(song),
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withOpacity(0.8),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.left,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ── 4 action icons ──
                        _ActionRow(
                          player: _player,
                          colorScheme: colorScheme,
                        ),

                        // ── Waveform progress & Controls stacked cleanly ──
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

                // ── Bottom Nav Bar Mock (matching demo) ──
                _BottomNavBar(
                  colorScheme: colorScheme,
                  onHome: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  onStats: () {
                    HapticFeedback.lightImpact();
                    _showAudioStatsSheet(context, song);
                  },
                  onSearch: () {
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.search_rounded, color: colorScheme.surface),
                            const SizedBox(width: 12),
                            const Text('Search anywhere to play next...'),
                          ],
                        ),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                  onMenu: () {
                    HapticFeedback.lightImpact();
                    if (widget.onQueueTap != null) {
                      Navigator.pop(context); // Close player to show queue
                      widget.onQueueTap!();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Up Next / Queue coming soon'),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
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
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SmallIconButton(
                    icon: isFav ? Icons.thumb_up_alt : Icons.thumb_up_off_alt,
                    isActive: isFav,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white70,
                    onPressed: () => onFavoriteToggle(song, isFav),
                  ),
                  const SizedBox(width: 16),
                  _SmallIconButton(
                    icon: Icons.thumb_down_off_alt,
                    isActive: false,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white70,
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
            color: Colors.white.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: _SmallIconButton(
            icon: Icons.more_vert_rounded,
            isActive: false,
            activeColor: Colors.white,
            inactiveColor: Colors.white70,
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
// Action Row — 4 icons: equalizer, timer, repeat, shuffle
// ═══════════════════════════════════════════════════════════════════════════

class _ActionRow extends StatelessWidget {
  final AudioPlayerManager player;
  final ColorScheme colorScheme;

  const _ActionRow({
    required this.player,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left Group (Eq, Timer)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionChip(
              icon: Icons.equalizer_rounded,
              tooltip: 'Equalizer',
              colorScheme: colorScheme,
              onPressed: () {
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Equalizer coming soon'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
            ),
            const SizedBox(width: 16),
            ValueListenableBuilder<Duration?>(
              valueListenable: player.sleepTimerRemaining,
              builder: (context, remaining, _) {
                final hasTimer = remaining != null;
                return _ActionChip(
                  icon: Icons.access_time_rounded,
                  tooltip: hasTimer ? 'Sleep Timer Active' : 'Sleep Timer',
                  isActive: hasTimer,
                  colorScheme: colorScheme,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _showSleepTimerSheet(context);
                  },
                );
              },
            ),
          ],
        ),

        // Right Group (Repeat, Shuffle)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<RepeatMode>(
              valueListenable: player.repeatMode,
              builder: (context, mode, _) {
                return _ActionChip(
                  icon: mode == RepeatMode.one
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
                  isActive: mode != RepeatMode.off,
                  colorScheme: colorScheme,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    player.toggleRepeatMode();
                  },
                );
              },
            ),
            const SizedBox(width: 16),
            ValueListenableBuilder<bool>(
              valueListenable: player.isShuffleEnabled,
              builder: (context, shuffleOn, _) {
                return _ActionChip(
                  icon: Icons.shuffle_rounded,
                  isActive: shuffleOn,
                  colorScheme: colorScheme,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    player.toggleShuffle();
                  },
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  void _showSleepTimerSheet(BuildContext context) {
    final options = [5, 10, 15, 30, 45, 60];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
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
                  color: colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sleep Timer',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            if (player.hasSleepTimer) ...[
              ListTile(
                leading: Icon(Icons.timer_off, color: colorScheme.error),
                title: const Text('Cancel Timer'),
                onTap: () {
                  player.cancelSleepTimer();
                  Navigator.pop(ctx);
                },
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              const SizedBox(height: 8),
            ],
            ...options.map(
              (m) => ListTile(
                leading:
                    Icon(Icons.bedtime_outlined, color: colorScheme.primary),
                title: Text('$m minutes'),
                onTap: () {
                  player.setSleepTimer(Duration(minutes: m));
                  Navigator.pop(ctx);
                },
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

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
                    ? Colors.white.withOpacity(0.3)
                    : Colors.white.withOpacity(0.12),
                border: widget.isActive
                    ? Border.all(
                        color: Colors.white,
                        width: 1.5,
                      )
                    : Border.all(color: Colors.transparent, width: 0),
              ),
              child: Icon(
                widget.icon,
                size: iconSize,
                color: Colors.white,
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
  final VoidCallback onHome;
  final VoidCallback onStats;
  final VoidCallback onSearch;
  final VoidCallback onMenu;

  const _BottomNavBar({
    required this.colorScheme,
    required this.onHome,
    required this.onStats,
    required this.onSearch,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A), // Matches exactly demo dark bottom look
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavIcon(
            icon: Icons.grid_view_rounded,
            isActive: true,
            colorScheme: colorScheme,
            onPressed: onHome,
          ),
          _NavIcon(
            icon: Icons.bar_chart_rounded,
            isActive: false,
            colorScheme: colorScheme,
            onPressed: onStats,
          ),
          _NavIcon(
            icon: Icons.search_rounded,
            isActive: false,
            colorScheme: colorScheme,
            onPressed: onSearch,
          ),
          _NavIcon(
            icon: Icons.menu_rounded,
            isActive: false,
            colorScheme: colorScheme,
            onPressed: onMenu,
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
