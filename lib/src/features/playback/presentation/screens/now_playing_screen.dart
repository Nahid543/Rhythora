// lib/src/features/playback/presentation/screens/now_playing_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';

import '../../../library/domain/entities/song.dart';
import '../../../library/data/playlist_repository.dart';
import '../../data/audio_player_manager.dart';
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

  // Gesture tracking
  double _verticalDragOffset = 0.0;
  double _horizontalDragOffset = 0.0;
  bool _isDragging = false;
  bool _isHorizontalDrag = false;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideController.forward();
    _fadeController.forward();

    _checkFirstTimeGesture();
    _checkFirstTimeMenuTutorial();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkFirstTimeMenuTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenMenu = prefs.getBool('has_seen_menu_tutorial') ?? false;

    if (!hasSeenMenu && mounted) {
      await Future.delayed(const Duration(milliseconds: 2500));
      if (mounted) {
        _showMenuTutorial();
        await prefs.setBool('has_seen_menu_tutorial', true);
      }
    }
  }

  void _showMenuTutorial() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: colorScheme.surface,
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colorScheme.primary, colorScheme.secondary],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.more_vert_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Discover More Options',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 22,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _MenuFeature(
                    icon: Icons.playlist_add_rounded,
                    text: 'Add to Playlist',
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 12),
                  _MenuFeature(
                    icon: Icons.info_outline_rounded,
                    text: 'Song Information',
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 12),
                  _MenuFeature(
                    icon: Icons.share_rounded,
                    text: 'Share Song',
                    colorScheme: colorScheme,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Tap the ⋮ button anytime to access these features',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Got it!'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
      ),
    );
  }

  Future<void> _checkFirstTimeGesture() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenGesture = prefs.getBool('has_seen_now_playing_gesture') ?? false;

    if (!hasSeenGesture && mounted) {
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) {
        _showGestureTutorial();
        await prefs.setBool('has_seen_now_playing_gesture', true);
      }
    }
  }

  void _showGestureTutorial() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: colorScheme.surface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withOpacity(0.2),
                    colorScheme.secondary.withOpacity(0.2),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.swipe_rounded,
                size: 56,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Gesture Controls',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _GestureHint(
              icon: Icons.arrow_downward_rounded,
              text: 'Swipe down to close',
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 12),
            _GestureHint(
              icon: Icons.arrow_back_rounded,
              text: 'Swipe left for next song',
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 12),
            _GestureHint(
              icon: Icons.arrow_forward_rounded,
              text: 'Swipe right for previous',
              colorScheme: colorScheme,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Got it!'),
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
      ),
    );
  }

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
            Text(
              isFavorite ? 'Removed from Favorites' : 'Added to Favorites ❤️',
            ),
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
                  Icon(
                    Icons.music_off_rounded,
                    size: 64,
                    color: colorScheme.primary.withOpacity(0.3),
                  ),
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
            backgroundColor: colorScheme.surface,
            appBar: _buildAppBar(currentSong, colorScheme),
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
                      child: _buildContent(
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

  PreferredSizeWidget _buildAppBar(Song song, ColorScheme colorScheme) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.surface.withOpacity(0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: IconButton(
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 32,
                color: colorScheme.onSurface,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop();
              },
            ),
          ),
        ),
      ),
      actions: [
        // Favorite Button
        ValueListenableBuilder<Set<String>>(
          valueListenable: _playlistRepo.favoriteSongIds,
          builder: (context, favorites, _) {
            final isFavorite = favorites.contains(song.id);
            return Container(
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: isFavorite
                    ? Colors.red.withOpacity(0.2)
                    : colorScheme.surface.withOpacity(0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: isFavorite
                        ? Colors.red.withOpacity(0.4)
                        : Colors.black.withOpacity(0.15),
                    blurRadius: isFavorite ? 16 : 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: IconButton(
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(
                          scale: animation,
                          child: RotationTransition(
                            turns: Tween<double>(begin: 0.8, end: 1.0)
                                .animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        key: ValueKey(isFavorite),
                        color: isFavorite ? Colors.red : colorScheme.onSurface,
                        size: 24,
                      ),
                    ),
                    onPressed: () => _handleFavoriteToggle(song, isFavorite),
                  ),
                ),
              ),
            );
          },
        ),

        // More Options Button
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: colorScheme.surface.withOpacity(0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: IconButton(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: colorScheme.onSurface,
                ),
                onPressed: () => _showActionsSheet(song),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ✅ FIXED: Layout that handles long text

  Widget _buildContent(
    Song song,
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isTablet,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewPadding = MediaQuery.of(context).viewPadding;
        final double usableHeight =
            constraints.maxHeight - viewPadding.top - viewPadding.bottom;
        final double fallbackHeight =
            usableHeight > 0 ? usableHeight : constraints.maxHeight;
        final bool isCompactHeight = fallbackHeight < 720;
        final bool isUltraCompactHeight = fallbackHeight < 640;

        final double horizontalPadding =
            isTablet ? 64 : (isCompactHeight ? 16 : 20);
        final double topSpacing =
            isTablet ? 32 : (isCompactHeight ? 18 : 24);
        final double sectionsGap =
            isTablet ? 36 : (isCompactHeight ? 18 : 28);
        final double titleGap = isCompactHeight ? 8 : 10;
        final double badgeGap = isCompactHeight ? 12 : 16;
        final double sliderGap = isCompactHeight ? 14 : 20;
        final double controlsGap = isCompactHeight ? 12 : 16;

        final double availableWidth =
            (constraints.maxWidth - (horizontalPadding * 2))
                .clamp(0.0, constraints.maxWidth);
        final double fallbackArtworkSize = isTablet
            ? 420
            : constraints.maxWidth * (isUltraCompactHeight ? 0.76 : 0.84);
        final double maxArtworkHeight = fallbackHeight *
            (isTablet ? 0.55 : (isUltraCompactHeight ? 0.4 : 0.48));
        final double resolvedArtworkSize = fallbackArtworkSize < maxArtworkHeight
            ? fallbackArtworkSize
            : maxArtworkHeight;
        final double artworkSize = resolvedArtworkSize
            .clamp(220.0, isTablet ? 520.0 : 360.0);
        final double queueWidthCap = isTablet ? 420.0 : 280.0;
        final double queueWidth = availableWidth > 0
            ? (availableWidth < queueWidthCap ? availableWidth : queueWidthCap)
            : queueWidthCap;
        final double titleFontSize =
            isTablet ? 28 : (isCompactHeight ? 20 : 22);

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: isCompactHeight ? 12 : 16,
            ),
            child: Column(
              key: ValueKey(song.id),
              children: [
                // Drag Handle
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),

                SizedBox(height: topSpacing),

                // Album Artwork
                Flexible(
                  flex: isTablet ? 5 : (isCompactHeight ? 5 : 6),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      height: artworkSize,
                      child: AlbumArtworkSection(
                        song: song,
                        colorScheme: colorScheme,
                        maxSize: artworkSize,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: sectionsGap),

                // Song Info & Controls
                Flexible(
                  flex: isTablet ? 4 : (isCompactHeight ? 6 : 5),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Song Title
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: availableWidth > 0
                              ? availableWidth * 0.9
                              : constraints.maxWidth * 0.88,
                          maxHeight: isCompactHeight ? 62 : 72,
                        ),
                        child: Text(
                          song.title,
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            height: 1.2,
                            fontSize: titleFontSize,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: isUltraCompactHeight ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      SizedBox(height: titleGap),

                      // Artist Badge
                      Container(
                        constraints: BoxConstraints(
                          maxWidth: availableWidth > 0
                              ? availableWidth * (isTablet ? 0.5 : 0.75)
                              : constraints.maxWidth * 0.7,
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompactHeight ? 12 : 16,
                          vertical: isCompactHeight ? 6 : 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primaryContainer.withOpacity(0.6),
                              colorScheme.secondaryContainer.withOpacity(0.6),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_rounded,
                              size: 16,
                              color: colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                song.artist.isEmpty ||
                                        song.artist == '<unknown>'
                                    ? 'Unknown Artist'
                                    : song.artist,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                  fontSize: isCompactHeight ? 12 : 13,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: badgeGap),

                      // Progress Slider
                      ProgressSliderSection(
                        player: _player,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),

                      SizedBox(height: sliderGap),

                      // Playback Controls
                      PlaybackControls(
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

                      SizedBox(height: controlsGap),

                      // Compact Queue Button (Always Visible)
                      Center(
                        child: _QueueButton(
                          onPressed: widget.onQueueTap,
                          colorScheme: colorScheme,
                          maxWidth: queueWidth,
                          isDense: isUltraCompactHeight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

}

// Compact Queue Button
class _QueueButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final ColorScheme colorScheme;
  final double maxWidth;
  final bool isDense;

  const _QueueButton({
    required this.onPressed,
    required this.colorScheme,
    this.maxWidth = double.infinity,
    this.isDense = false,
  });

  @override
  State<_QueueButton> createState() => _QueueButtonState();
}

class _QueueButtonState extends State<_QueueButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onPressed != null) {
      HapticFeedback.lightImpact();
      _controller.forward().then((_) => _controller.reverse());
      widget.onPressed!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        final bool hasFiniteWidth = widget.maxWidth.isFinite;
        final double maxWidth =
            hasFiniteWidth ? widget.maxWidth : double.infinity;
        double minWidth = hasFiniteWidth ? widget.maxWidth * 0.65 : 0.0;
        if (hasFiniteWidth && minWidth > widget.maxWidth) {
          minWidth = widget.maxWidth;
        }

        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _handleTap,
              borderRadius: BorderRadius.circular(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxWidth,
                  minWidth: minWidth,
                ),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.isDense ? 18 : 24,
                    vertical: widget.isDense ? 10 : 12,
                  ),
                  decoration: BoxDecoration(
                    color: widget.colorScheme.surfaceVariant.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: widget.colorScheme.outline.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.queue_music_rounded,
                        color: widget.colorScheme.onSurfaceVariant,
                        size: widget.isDense ? 18 : 20,
                      ),
                      SizedBox(width: widget.isDense ? 6 : 8),
                      Text(
                        'Queue',
                        style: TextStyle(
                          fontSize: widget.isDense ? 13 : 14,
                          fontWeight: FontWeight.w600,
                          color: widget.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Menu Feature Widget
class _MenuFeature extends StatelessWidget {
  final IconData icon;
  final String text;
  final ColorScheme colorScheme;

  const _MenuFeature({
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
            color: colorScheme.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withOpacity(0.9),
            ),
          ),
        ),
        Icon(
          Icons.check_circle,
          size: 18,
          color: colorScheme.primary.withOpacity(0.6),
        ),
      ],
    );
  }
}

// Gesture Hint Widget
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
