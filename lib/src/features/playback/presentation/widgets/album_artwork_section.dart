import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:io';

import '../../../library/domain/entities/song.dart';
import '../../data/audio_player_manager.dart';
import '../../../library/data/local_music_loader.dart';

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
  
  String? _resolvedPath;
  bool _isLoading = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();

    _resolvedPath = widget.song.albumArtPath;
    if (_resolvedPath == null) {
      _loadArtworkLazily();
    }

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutBack,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
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
  void didUpdateWidget(AlbumArtworkSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id ||
        oldWidget.song.albumArtPath != widget.song.albumArtPath) {
      _resolvedPath = widget.song.albumArtPath;
      _loadFailed = false;
      if (_resolvedPath == null) {
        _loadArtworkLazily();
      }
    }
  }

  Future<void> _loadArtworkLazily() async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      final songIdInt = int.tryParse(widget.song.id);
      if (songIdInt == null) {
        _isLoading = false;
        return;
      }

      final path = await LocalMusicLoader.instance.getOrCacheArtwork(songIdInt);
      if (mounted && path != null) {
        setState(() {
          _resolvedPath = path;
          _isLoading = false;
        });
      } else {
        _isLoading = false;
      }
    } catch (_) {
      _isLoading = false;
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
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    // Use almost the full width of the screen, matching the demo exactly
    final double defaultMaxSize =
        isTablet ? size.width * 0.55 : size.width * 0.85;
    final double minSize = isTablet ? 240.0 : 200.0;
    final double artworkSize = widget.maxSize != null
        ? widget.maxSize!.clamp(minSize, defaultMaxSize)
        : defaultMaxSize.clamp(minSize, defaultMaxSize);

    final borderRadius = BorderRadius.circular(isTablet ? 32 : 24);

    return Center(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            final shadowOpacity = 0.25 * _pulseAnimation.value;
            final spread = 12 * _pulseAnimation.value;

            return Hero(
              tag: 'artwork_${widget.song.id}',
              child: Container(
                width: artworkSize,
                height: artworkSize,
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  boxShadow: [
                    BoxShadow(
                      color: widget.colorScheme.primary.withOpacity(shadowOpacity),
                      blurRadius: 40,
                      spreadRadius: spread,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                        // Load artwork from file if available, otherwise show fallback
                        if (_resolvedPath != null && !_loadFailed)
                          Image.file(
                            File(_resolvedPath!),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) setState(() => _loadFailed = true);
                              });
                              return _StunningNoArtwork(
                                colorScheme: widget.colorScheme,
                                rotateController: _rotateController,
                                waveController: _waveController,
                                pulseAnimation: _pulseAnimation,
                                isPlaying: _player.isPlaying,
                              );
                            },
                          )
                        else
                          _StunningNoArtwork(
                            colorScheme: widget.colorScheme,
                            rotateController: _rotateController,
                            waveController: _waveController,
                            pulseAnimation: _pulseAnimation,
                            isPlaying: _player.isPlaying,
                          ),
                      // Subtle inner shadow overlay for depth
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: borderRadius,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.1),
                              Colors.transparent,
                              Colors.black.withOpacity(0.35),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
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
}

class _StunningNoArtwork extends StatelessWidget {
  final ColorScheme colorScheme;
  final AnimationController rotateController;
  final AnimationController waveController;
  final Animation<double> pulseAnimation;
  final ValueNotifier<bool> isPlaying;

  const _StunningNoArtwork({
    required this.colorScheme,
    required this.rotateController,
    required this.waveController,
    required this.pulseAnimation,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Rotating gradient background
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
                  stops: const [0.0, 0.35, 0.7, 1.0],
                  transform: GradientRotation(
                    rotateController.value * 2 * math.pi,
                  ),
                ),
              ),
            );
          },
        ),

        // Wave circles
        ValueListenableBuilder<bool>(
          valueListenable: isPlaying,
          builder: (context, playing, _) {
            if (!playing) return const SizedBox.shrink();
            return AnimatedBuilder(
              animation: waveController,
              builder: (context, child) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    return CustomPaint(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      painter: _WaveCirclesPainter(
                        animation: waveController.value,
                        color: Colors.white.withOpacity(0.25),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),

        // Dark overlay
        Container(
          color: Colors.black.withOpacity(0.15),
        ),

        // Music icon
        Center(
          child: AnimatedBuilder(
            animation: pulseAnimation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withOpacity(0.2 * pulseAnimation.value),
                          Colors.white.withOpacity(0.05 * pulseAnimation.value),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Icon(
                    Icons.music_note_rounded,
                    size: 72,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                      Shadow(
                        color: colorScheme.primary.withOpacity(0.5),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WaveCirclesPainter extends CustomPainter {
  final double animation;
  final Color color;

  _WaveCirclesPainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.max(size.width, size.height) * 0.8;
    const circleCount = 3;

    for (int i = 0; i < circleCount; i++) {
      final progress = (animation + i * 0.33) % 1.0;
      final radius = maxRadius * progress;
      final opacity = (1 - progress) * 0.5;

      final paint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveCirclesPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}
