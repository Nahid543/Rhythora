import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;

import '../../data/audio_player_manager.dart';

/// A waveform-style progress visualizer with floating time badges.
class ProgressSliderSection extends StatefulWidget {
  final AudioPlayerManager player;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final Widget? childControls;

  const ProgressSliderSection({
    super.key,
    required this.player,
    required this.colorScheme,
    required this.textTheme,
    this.childControls,
  });

  @override
  State<ProgressSliderSection> createState() => _ProgressSliderSectionState();
}

class _ProgressSliderSectionState extends State<ProgressSliderSection> {
  bool _isDragging = false;
  Duration _dragPosition = Duration.zero;
  Timer? _seekDebounce;
  double _dragStartX = 0.0;
  Duration _dragStartPos = Duration.zero;

  @override
  void dispose() {
    _seekDebounce?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    if (d.inHours > 0) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60);
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$h:${m.toString().padLeft(2, '0')}:$s';
    }
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  int _computeTotalBars(Duration dur) {
    final durSecs = dur.inSeconds;
    if (durSecs == 0) return 100;
    return (durSecs * 3).clamp(50, 3000); // 3 bars per second
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _dragStartX = details.globalPosition.dx;
      _dragStartPos = widget.player.position.value;
    });
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details, double totalWaveformWidth) {
    final durMs = widget.player.duration.value.inMilliseconds;
    if (durMs == 0 || totalWaveformWidth == 0) return;

    // Moving finger to the right (+dx) moves the waveform right -> going backwards in time
    final dx = details.globalPosition.dx - _dragStartX;
    final msChange = (-dx / totalWaveformWidth * durMs).toInt();

    setState(() {
      final newMs = _dragStartPos.inMilliseconds + msChange;
      final clampedMs = newMs.clamp(0, durMs);
      _dragPosition = Duration(milliseconds: clampedMs);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    _seekDebounce?.cancel();
    _seekDebounce = Timer(const Duration(milliseconds: 50), () {
      widget.player.seek(_dragPosition);
      setState(() {
        _isDragging = false;
      });
    });
  }

  void _onTapUp(TapUpDetails details, double waveWidth, double totalWaveformWidth) {
    final durMs = widget.player.duration.value.inMilliseconds;
    if (durMs == 0 || totalWaveformWidth == 0) return;

    final playheadX = waveWidth / 2;
    final tapDx = details.localPosition.dx - playheadX;
    final msChange = (tapDx / totalWaveformWidth * durMs).toInt();

    final currentMs = widget.player.position.value.inMilliseconds;
    final newMs = (currentMs + msChange).clamp(0, durMs);
    widget.player.seek(Duration(milliseconds: newMs));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Duration>(
      valueListenable: widget.player.position,
      builder: (context, position, _) {
        return ValueListenableBuilder<Duration>(
          valueListenable: widget.player.duration,
          builder: (context, duration, _) {
            final total = duration.inMilliseconds == 0 ? 1 : duration.inMilliseconds;
            final double progress = _isDragging
                ? (_dragPosition.inMilliseconds / total).clamp(0.0, 1.0)
                : (position.inMilliseconds / total).clamp(0.0, 1.0);

            final displayPosition = _isDragging ? _dragPosition : position;

            final totalBars = _computeTotalBars(duration);
            const advance = 6.0;
            final totalWaveformWidth = (totalBars - 1) * advance;

            return LayoutBuilder(
              builder: (context, constraints) {
                final waveWidth = constraints.maxWidth;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: _onHorizontalDragStart,
                  onHorizontalDragUpdate: (details) =>
                      _onHorizontalDragUpdate(details, totalWaveformWidth),
                  onHorizontalDragEnd: _onHorizontalDragEnd,
                  onTapUp: (details) => _onTapUp(details, waveWidth, totalWaveformWidth),
                  child: SizedBox(
                    height: 140, // Taller to accommodate overlapping playback controls and massive waveform
                    width: waveWidth,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 1. Scrolling Waveform visualizer 
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _WaveformPainter(
                                progress: progress,
                                activeColor: widget.colorScheme.onSurface,
                                inactiveColor: widget.colorScheme.onSurface.withOpacity(0.3),
                                totalBars: totalBars,
                              ),
                            ),
                          ),
                        ),

                        // 1.5 Center Scrubbing Playhead Line (visible only when dragging)
                        Positioned(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _isDragging ? 1.0 : 0.0,
                            child: Container(
                              width: 2,
                              height: 120, // Slightly shorter than the full box
                                decoration: BoxDecoration(
                                  color: widget.colorScheme.onSurface,
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.5),
                                      blurRadius: 4,
                                    )
                                  ],
                                ),
                            ),
                          ),
                        ),

                        // 2. Playback Controls (fades out while scrubbing)
                        if (widget.childControls != null) 
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _isDragging ? 0.0 : 1.0,
                            child: widget.childControls!,
                          ),

                        // 3. Floating Time Badges matching the demo
                        Positioned(
                          left: 4,
                          bottom: 0, // Lowered slightly given the taller box
                          child: IgnorePointer(
                            child: _TimeBadge(
                              time: _format(displayPosition),
                              colorScheme: widget.colorScheme,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 4,
                          bottom: 0,
                          child: IgnorePointer(
                            child: _TimeBadge(
                              time: _format(duration),
                              colorScheme: widget.colorScheme,
                            ),
                          ),
                        ),
                      ],
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
}

class _TimeBadge extends StatelessWidget {
  final String time;
  final ColorScheme colorScheme;

  const _TimeBadge({required this.time, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        time,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final int totalBars;

  _WaveformPainter({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    required this.totalBars,
  });

  // Deterministic pseudo-random pattern long enough to not repeat obviously
  static final List<double> _pattern = List.generate(3000, (i) {
    final x = i.toDouble();
    final v1 = math.sin(x * 0.1) * 0.4;
    final v2 = math.sin(x * 0.3 + 1.2) * 0.3;
    final v3 = math.sin(x * 0.7 + 2.5) * 0.2;
    return (0.35 + v1 + v2 + v3).clamp(0.15, 1.0);
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxBarHeight = size.height - 24; // Room for time badges
    // Adjusted advance and barWidth for a tighter, smoother, premium look
    const advance = 5.0;
    const barWidth = 3.5;
    final playheadX = size.width / 2;
    
    final totalWaveformWidth = (totalBars - 1) * advance;
    final currentScroll = progress * totalWaveformWidth; 

    // Window size for spatial smoothing (average of N neighbors)
    const smoothRadius = 2;

    for (int i = 0; i < totalBars; i++) {
      final barLocalX = i * advance;
      final screenX = playheadX + barLocalX - currentScroll;
      
      // Strict culling with a bit of buffer
      if (screenX < -20 || screenX > size.width + 20) continue;

      // --- Organic Spatial Smoothing ---
      // Instead of raw discrete values, we blend neighboring pattern values
      // to create cohesive "peaks" and "valleys" instead of random noise.
      double sum = 0.0;
      int count = 0;
      for (int j = i - smoothRadius; j <= i + smoothRadius; j++) {
        if (j >= 0 && j < totalBars) {
          sum += _pattern[j % _pattern.length];
          count++;
        }
      }
      final smoothedHeightFraction = sum / count;
      // ------------------------------------

      final barHeight = smoothedHeightFraction * maxBarHeight;
      
      // Vertically center the bars
      final y = (size.height - barHeight) / 2;

      final isActive = screenX <= playheadX;
      
      final paint = Paint()
        ..color = isActive 
            ? Colors.white.withOpacity(0.9) 
            : Colors.white.withOpacity(0.2)
        ..style = PaintingStyle.fill;
        
      // Fully rounded circular caps for ultra-smooth pill aesthetic
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(screenX, y, barWidth, barHeight),
          const Radius.circular(999.0), 
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.totalBars != totalBars;
  }
}
