import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'dart:ui';

import '../../../library/domain/entities/song.dart';
import '../../data/audio_player_manager.dart';
import '../../data/dynamic_color_service.dart';

class MiniPlayerBar extends StatefulWidget {
  final VoidCallback onTap;

  const MiniPlayerBar({
    super.key,
    required this.onTap,
  });

  @override
  State<MiniPlayerBar> createState() => _MiniPlayerBarState();
}

class _MiniPlayerBarState extends State<MiniPlayerBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  final AudioPlayerManager _player = AudioPlayerManager.instance;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeIn,
      ),
    );

    _player.currentSong.addListener(_onSongChanged);

    if (_player.currentSong.value != null) {
      _slideController.forward();
    }
  }

  void _onSongChanged() {
    if (_player.currentSong.value != null && !_slideController.isCompleted) {
      _slideController.forward();
    } else if (_player.currentSong.value == null &&
        _slideController.isCompleted) {
      _slideController.reverse();
    }
  }

  @override
  void dispose() {
    _player.currentSong.removeListener(_onSongChanged);
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Song?>(
      valueListenable: _player.currentSong,
      builder: (context, currentSong, _) {
        if (currentSong == null) {
          return const SizedBox.shrink();
        }

        // Extra safety: hide if duration is invalid/zero
        return ValueListenableBuilder<Duration>(
          valueListenable: _player.duration,
          builder: (context, duration, __) {
            if (duration.inMilliseconds <= 0) {
              return const SizedBox.shrink();
            }
            return _buildMiniPlayer(context, currentSong);
          },
        );
      },
    );
  }

  Widget _buildMiniPlayer(BuildContext context, Song song) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final artworkId = int.tryParse(song.id) ?? 0;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ListenableBuilder(
          listenable: DynamicColorService.instance,
          builder: (context, child) {
            final dominantColor = DynamicColorService.instance.dominantColor;
            
            return Container(
              margin: EdgeInsets.symmetric(horizontal: isTablet ? 40 : 16),
              // True Floating Pill Decoration
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40), // Perfectly rounded pill
                // Optimized rendering with opaque colors instead of BackdropFilter
                color: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF8F9FA),
                border: Border.all(
                  color: dominantColor.withValues(alpha: isDark ? 0.3 : 0.2), // Dynamic border
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                    blurRadius: 24,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                  // Dynamic subtle glow beneath
                  BoxShadow(
                    color: dominantColor.withValues(alpha: isDark ? 0.25 : 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: Material(
                  color: Colors.transparent,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      InkWell(
                        onTap: widget.onTap,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 8, 
                            top: 8, 
                            bottom: 8, 
                            right: 16
                          ),
                          child: Row(
                            children: [
                              _buildArtwork(song, artworkId, colorScheme, isTablet),
                              SizedBox(width: isTablet ? 16 : 14),
                              Expanded(
                                child: _buildSongInfo(song, colorScheme, textTheme),
                              ),
                              SizedBox(width: isTablet ? 16 : 8),
                              _buildControls(colorScheme, isTablet, isDark),
                            ],
                          ),
                        ),
                      ),
                      // Progress bar integrated into the bottom lip of the pill
                      _buildProgressBar(colorScheme),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProgressBar(ColorScheme colorScheme) {
    return ValueListenableBuilder<Duration>(
      valueListenable: _player.position,
      builder: (context, position, _) {
        return ValueListenableBuilder<Duration>(
          valueListenable: _player.duration,
          builder: (context, duration, _) {
            final progress = duration.inMilliseconds > 0
                ? position.inMilliseconds / duration.inMilliseconds
                : 0.0;

            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: progress.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                final dominantColor = DynamicColorService.instance.dominantColor;
                return Container(
                  height: 3, // Thinner, minimalist stroke
                  width: double.infinity,
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: value,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            dominantColor,
                            dominantColor.withValues(alpha: 0.7),
                            colorScheme.tertiary,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: dominantColor.withValues(alpha: 0.5),
                            blurRadius: 6,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildArtwork(
    Song song,
    int artworkId,
    ColorScheme colorScheme,
    bool isTablet,
  ) {
    final size = isTablet ? 56.0 : 48.0;

    return Hero(
      tag: 'artwork_${song.id}',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle, // Circular artwork fits pill perfectly
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: QueryArtworkWidget(
            id: artworkId,
            type: ArtworkType.AUDIO,
            artworkFit: BoxFit.cover,
            artworkBorder: BorderRadius.zero,
            quality: 100,
            nullArtworkWidget: Container(
              color: colorScheme.surfaceVariant,
              child: Icon(
                Icons.music_note_rounded,
                color: colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSongInfo(
    Song song,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          song.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.6),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildControls(ColorScheme colorScheme, bool isTablet, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FlatIconButton(
          icon: Icons.skip_previous_rounded,
          size: isTablet ? 42 : 38,
          iconSize: isTablet ? 26 : 24,
          onPressed: () {
            HapticFeedback.mediumImpact();
            _player.skipToPrevious();
          },
          color: colorScheme.onSurface.withOpacity(0.6),
        ),
        SizedBox(width: isTablet ? 8 : 4),
        ValueListenableBuilder<bool>(
          valueListenable: _player.isPlaying,
          builder: (context, isPlaying, _) {
            return _FlatIconButton(
              icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: isTablet ? 48 : 44,
              iconSize: isTablet ? 30 : 28,
              onPressed: () {
                HapticFeedback.lightImpact();
                if (isPlaying) {
                  _player.pause();
                } else {
                  _player.play();
                }
              },
              color: isPlaying 
                  ? colorScheme.primary 
                  : colorScheme.onSurface.withOpacity(0.8),
            );
          },
        ),
        SizedBox(width: isTablet ? 8 : 4),
        _FlatIconButton(
          icon: Icons.skip_next_rounded,
          size: isTablet ? 42 : 38,
          iconSize: isTablet ? 26 : 24,
          onPressed: () {
            HapticFeedback.mediumImpact();
            _player.skipToNext();
          },
          color: colorScheme.onSurface.withOpacity(0.6),
        ),
      ],
    );
  }
}

class _FlatIconButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final VoidCallback onPressed;
  final Color color;

  const _FlatIconButton({
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.onPressed,
    required this.color,
  });

  @override
  State<_FlatIconButton> createState() => _FlatIconButtonState();
}

class _FlatIconButtonState extends State<_FlatIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _scaleController.forward().then((_) {
      if (mounted) _scaleController.reverse();
    });
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Center(
                child: Icon(
                  widget.icon,
                  size: widget.iconSize,
                  color: widget.color,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
