import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'dart:ui';

import '../../../library/domain/entities/song.dart';
import '../../data/audio_player_manager.dart';

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
    final artworkId = int.tryParse(song.id) ?? 0;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: EdgeInsets.fromLTRB(
            isTablet ? 20 : 12,
            8,
            isTablet ? 20 : 12,
            isTablet ? 20 : 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 25,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.15),
                blurRadius: 20,
                spreadRadius: -5,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.surfaceVariant.withOpacity(0.95),
                      colorScheme.surface.withOpacity(0.98),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.15),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildProgressBar(colorScheme),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: widget.onTap,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 20 : 16,
                            vertical: isTablet ? 16 : 14,
                          ),
                          child: Row(
                            children: [
                              _buildArtwork(
                                song,
                                artworkId,
                                colorScheme,
                                isTablet,
                              ),
                              SizedBox(width: isTablet ? 16 : 14),
                              Expanded(
                                child: _buildSongInfo(
                                  song,
                                  colorScheme,
                                  textTheme,
                                ),
                              ),
                              SizedBox(width: isTablet ? 16 : 12),
                              _buildControls(colorScheme, isTablet),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
              curve: Curves.easeOut,
              builder: (context, value, _) {
                return Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant.withOpacity(0.5),
                  ),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: value,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary,
                            colorScheme.secondary,
                            colorScheme.tertiary,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
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
    final size = isTablet ? 60.0 : 52.0;

    return Hero(
      tag: 'artwork_${song.id}',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.3),
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: QueryArtworkWidget(
            id: artworkId,
            type: ArtworkType.AUDIO,
            artworkFit: BoxFit.cover,
            artworkBorder: BorderRadius.zero,
            quality: 100,
            nullArtworkWidget: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary.withOpacity(0.8),
                    colorScheme.secondary.withOpacity(0.6),
                    colorScheme.tertiary.withOpacity(0.4),
                  ],
                ),
              ),
              child: Icon(
                Icons.music_note_rounded,
                color: Colors.white,
                size: isTablet ? 28 : 24,
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
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_rounded,
                    size: 12,
                    color: colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildControls(ColorScheme colorScheme, bool isTablet) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CircleButton(
          icon: Icons.skip_previous_rounded,
          size: isTablet ? 42 : 38,
          iconSize: isTablet ? 24 : 22,
          onPressed: () => _player.skipToPrevious(),
          colorScheme: colorScheme,
          isPrimary: false,
        ),
        SizedBox(width: isTablet ? 10 : 8),
        ValueListenableBuilder<bool>(
          valueListenable: _player.isPlaying,
          builder: (context, isPlaying, _) {
            return _CircleButton(
              icon: isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              size: isTablet ? 52 : 48,
              iconSize: isTablet ? 28 : 26,
              onPressed: () {
                if (isPlaying) {
                  _player.pause();
                } else {
                  _player.play();
                }
              },
              colorScheme: colorScheme,
              isPrimary: true,
            );
          },
        ),
        SizedBox(width: isTablet ? 10 : 8),
        _CircleButton(
          icon: Icons.skip_next_rounded,
          size: isTablet ? 42 : 38,
          iconSize: isTablet ? 24 : 22,
          onPressed: () => _player.skipToNext(),
          colorScheme: colorScheme,
          isPrimary: false,
        ),
      ],
    );
  }
}

class _CircleButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final VoidCallback onPressed;
  final ColorScheme colorScheme;
  final bool isPrimary;

  const _CircleButton({
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.onPressed,
    required this.colorScheme,
    required this.isPrimary,
  });

  @override
  State<_CircleButton> createState() => _CircleButtonState();
}

class _CircleButtonState extends State<_CircleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _scaleController.forward().then((_) {
      _scaleController.reverse();
    });
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: widget.isPrimary
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          widget.colorScheme.primary,
                          widget.colorScheme.secondary,
                        ],
                      )
                    : null,
                color: widget.isPrimary
                    ? null
                    : widget.colorScheme.surfaceVariant.withOpacity(0.8),
                boxShadow: widget.isPrimary
                    ? [
                        BoxShadow(
                          color:
                              widget.colorScheme.primary.withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 1,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Icon(
                widget.icon,
                size: widget.iconSize,
                color: widget.isPrimary
                    ? Colors.white
                    : widget.colorScheme.onSurface,
              ),
            ),
          );
        },
      ),
    );
  }
}
