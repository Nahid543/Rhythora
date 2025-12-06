import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'dart:math' as math;

import '../../../library/domain/entities/song.dart';
import '../../data/audio_player_manager.dart';

class AlbumArtworkSection extends StatefulWidget {
  final Song song;
  final ColorScheme colorScheme;
  final double? maxSize;

  const AlbumArtworkSection({
    super.key,
    required this.song,
    required this.colorScheme,
    this.maxSize,
  });

  @override
  State<AlbumArtworkSection> createState() => _AlbumArtworkSectionState();
}

class _AlbumArtworkSectionState extends State<AlbumArtworkSection>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late AnimationController _waveController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  final AudioPlayerManager _player = AudioPlayerManager.instance;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutBack,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    _scaleController.forward();

    _player.isPlaying.addListener(_onPlaybackChanged);
  }

  void _onPlaybackChanged() {
    if (!_player.isPlaying.value) {
      _pulseController.stop();
      _waveController.stop();
    } else {
      if (!_pulseController.isAnimating) _pulseController.repeat(reverse: true);
      if (!_waveController.isAnimating) _waveController.repeat();
    }
  }

  @override
  void dispose() {
    _player.isPlaying.removeListener(_onPlaybackChanged);
    _scaleController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final artworkId = int.tryParse(widget.song.id) ?? 0;
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final double fallbackSize = isTablet ? 380.0 : size.width * 0.82;
    final double maxByViewport =
        isTablet ? size.width * 0.65 : size.width * 0.95;
    final double minSize = isTablet ? 220.0 : 180.0;
    final double artworkSize = widget.maxSize != null
        ? widget.maxSize!.clamp(minSize, maxByViewport)
        : fallbackSize.clamp(minSize, maxByViewport);

    return Center(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SizedBox(
          width: artworkSize,
          height: artworkSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Subtle background glow ONLY
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Container(
                    width: artworkSize * 1.15,
                    height: artworkSize * 1.15,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          widget.colorScheme.primary.withOpacity(
                            0.2 * _pulseAnimation.value,
                          ),
                          widget.colorScheme.secondary.withOpacity(
                            0.1 * _pulseAnimation.value,
                          ),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  );
                },
              ),

              // Main artwork
              Hero(
                tag: 'artwork_${widget.song.id}',
                child: Container(
                  width: artworkSize,
                  height: artworkSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: widget.colorScheme.primary.withOpacity(0.25),
                        blurRadius: 30,
                        spreadRadius: 3,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: QueryArtworkWidget(
                      id: artworkId,
                      type: ArtworkType.AUDIO,
                      artworkFit: BoxFit.cover,
                      artworkBorder: BorderRadius.zero,
                      quality: 100,
                      nullArtworkWidget: _StunningNoArtwork(
                        size: artworkSize,
                        colorScheme: widget.colorScheme,
                        rotateController: _rotateController,
                        waveController: _waveController,
                        pulseAnimation: _pulseAnimation,
                        isPlaying: _player.isPlaying,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Enhanced No-Artwork Widget
class _StunningNoArtwork extends StatelessWidget {
  final double size;
  final ColorScheme colorScheme;
  final AnimationController rotateController;
  final AnimationController waveController;
  final Animation<double> pulseAnimation;
  final ValueNotifier<bool> isPlaying;

  const _StunningNoArtwork({
    required this.size,
    required this.colorScheme,
    required this.rotateController,
    required this.waveController,
    required this.pulseAnimation,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Animated rotating gradient
        AnimatedBuilder(
          animation: rotateController,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: SweepGradient(
                  colors: [
                    colorScheme.primary,
                    colorScheme.secondary,
                    colorScheme.tertiary,
                    colorScheme.primary,
                  ],
                  stops: const [0.0, 0.4, 0.7, 1.0],
                  transform: GradientRotation(
                    rotateController.value * 2 * math.pi,
                  ),
                ),
              ),
            );
          },
        ),

        // Animated wave circles (when playing)
        ValueListenableBuilder<bool>(
          valueListenable: isPlaying,
          builder: (context, playing, _) {
            return playing
                ? AnimatedBuilder(
                    animation: waveController,
                    builder: (context, child) {
                      return CustomPaint(
                        size: Size(size, size),
                        painter: _WaveCirclesPainter(
                          animation: waveController.value,
                          color: Colors.white.withOpacity(0.3),
                        ),
                      );
                    },
                  )
                : const SizedBox.shrink();
          },
        ),

        // Subtle overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.black.withOpacity(0.2),
                Colors.transparent,
                Colors.black.withOpacity(0.3),
              ],
            ),
          ),
        ),

        // Pulsing center glow + icon
        Center(
          child: AnimatedBuilder(
            animation: pulseAnimation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Glowing background
                  Container(
                    width: size * 0.45,
                    height: size * 0.45,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withOpacity(0.25 * pulseAnimation.value),
                          Colors.white.withOpacity(0.1 * pulseAnimation.value),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  // Outer icon (glow)
                  Icon(
                    Icons.music_note_rounded,
                    size: size * 0.36,
                    color: Colors.white.withOpacity(0.2),
                  ),
                  // Main icon
                  Icon(
                    Icons.music_note_rounded,
                    size: size * 0.3,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                      Shadow(
                        color: colorScheme.primary.withOpacity(0.6),
                        blurRadius: 25,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),

        // Floating particles (when playing)
        ValueListenableBuilder<bool>(
          valueListenable: isPlaying,
          builder: (context, playing, _) {
            return playing
                ? AnimatedBuilder(
                    animation: waveController,
                    builder: (context, child) {
                      return CustomPaint(
                        size: Size(size, size),
                        painter: _FloatingParticlesPainter(
                          animation: waveController.value,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      );
                    },
                  )
                : const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}

// Wave Circles Painter
class _WaveCirclesPainter extends CustomPainter {
  final double animation;
  final Color color;

  _WaveCirclesPainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const circleCount = 4;

    for (int i = 0; i < circleCount; i++) {
      final progress = (animation + i * 0.25) % 1.0;
      final radius = size.width * 0.15 * (1 + progress * 2.5);
      final opacity = (1 - progress) * 0.4;

      final paint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveCirclesPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}

// Floating Particles Painter
class _FloatingParticlesPainter extends CustomPainter {
  final double animation;
  final Color color;

  _FloatingParticlesPainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    const particleCount = 15;

    for (int i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 2 * math.pi;
      final progress = (animation + i * 0.067) % 1.0;

      final distance = size.width * 0.2 * progress;
      final x =
          size.width / 2 + math.cos(angle + animation * math.pi) * distance;
      final y =
          size.height / 2 + math.sin(angle + animation * math.pi) * distance;

      final opacity = (1 - progress) * 0.7;
      final particleSize = 2.5 * (1 - progress * 0.4);

      paint.color = color.withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), particleSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingParticlesPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}
