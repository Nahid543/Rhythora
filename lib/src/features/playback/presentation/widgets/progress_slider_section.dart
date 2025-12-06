// lib/src/features/playback/presentation/widgets/progress_slider_section.dart

import 'package:flutter/material.dart';
import 'dart:async';

import '../../data/audio_player_manager.dart';

/// Production-ready progress slider with:
/// - Debounced seeking
/// - Smooth animations
/// - Better visual feedback
/// - Performance optimized
class ProgressSliderSection extends StatefulWidget {
  final AudioPlayerManager player;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const ProgressSliderSection({
    super.key,
    required this.player,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  State<ProgressSliderSection> createState() => _ProgressSliderSectionState();
}

class _ProgressSliderSectionState extends State<ProgressSliderSection> {
  bool _isDragging = false;
  double _dragValue = 0.0;
  Timer? _seekDebounce;

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

  void _onSeekStart(double value) {
    setState(() {
      _isDragging = true;
      _dragValue = value;
    });
  }

  void _onSeekUpdate(double value) {
    setState(() {
      _dragValue = value;
    });
  }

  void _onSeekEnd(double value) {
    // Debounce seeking for performance
    _seekDebounce?.cancel();
    _seekDebounce = Timer(const Duration(milliseconds: 100), () {
      widget.player.seek(Duration(milliseconds: value.toInt()));
      setState(() {
        _isDragging = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Progress indicator bar
        ValueListenableBuilder<Duration>(
          valueListenable: widget.player.position,
          builder: (context, position, _) {
            return ValueListenableBuilder<Duration>(
              valueListenable: widget.player.duration,
              builder: (context, duration, _) {
                final total = duration.inMilliseconds == 0 ? 1 : duration.inMilliseconds;
                final currentValue = _isDragging 
                    ? _dragValue 
                    : position.inMilliseconds.clamp(0, total).toDouble();

                return Column(
                  children: [
                    // Custom slider
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 5,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 8,
                          elevation: 3,
                          pressedElevation: 5,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 18,
                        ),
                        activeTrackColor: widget.colorScheme.primary,
                        inactiveTrackColor: widget.colorScheme.surfaceVariant.withOpacity(0.5),
                        thumbColor: widget.colorScheme.primary,
                        overlayColor: widget.colorScheme.primary.withOpacity(0.2),
                        valueIndicatorColor: widget.colorScheme.primary,
                        valueIndicatorTextStyle: TextStyle(
                          color: widget.colorScheme.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Slider(
                        value: currentValue,
                        min: 0,
                        max: total.toDouble(),
                        onChangeStart: _onSeekStart,
                        onChanged: _onSeekUpdate,
                        onChangeEnd: _onSeekEnd,
                      ),
                    ),

                    // Time labels
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Current position
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: widget.textTheme.bodySmall!.copyWith(
                              color: _isDragging
                                  ? widget.colorScheme.primary
                                  : widget.colorScheme.onSurface.withOpacity(0.7),
                              fontWeight: _isDragging ? FontWeight.w700 : FontWeight.w600,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                            child: Text(
                              _format(
                                _isDragging
                                    ? Duration(milliseconds: _dragValue.toInt())
                                    : position,
                              ),
                            ),
                          ),

                          // Remaining time (more useful than total)
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: widget.textTheme.bodySmall!.copyWith(
                              color: widget.colorScheme.onSurface.withOpacity(0.6),
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                            child: Text(
                              '-${_format(duration - (_isDragging 
                                  ? Duration(milliseconds: _dragValue.toInt())
                                  : position))}',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}
