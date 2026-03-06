
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/audio_player_manager.dart';

class PlaybackControls extends StatelessWidget {
  final AudioPlayerManager player;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final ColorScheme colorScheme;

  const PlaybackControls({
    super.key,
    required this.player,
    required this.onNext,
    required this.onPrevious,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return ValueListenableBuilder<bool>(
      valueListenable: player.isPlaying,
      builder: (context, isPlaying, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Fast rewind (10s back)
            _CircleControlButton(
              icon: Icons.fast_rewind_rounded,
              iconSize: isTablet ? 30 : 26,
              buttonSize: isTablet ? 52 : 46,
              isSolid: false,
              tooltip: 'Rewind 10s',
              onPressed: () {
                HapticFeedback.lightImpact();
                final pos = player.position.value;
                final newPos = pos - const Duration(seconds: 10);
                player.seek(
                  newPos < Duration.zero ? Duration.zero : newPos,
                );
              },
              colorScheme: colorScheme,
            ),

            SizedBox(width: isTablet ? 16 : 12),

            // Previous
            _CircleControlButton(
              icon: Icons.skip_previous_rounded,
              iconSize: isTablet ? 36 : 30,
              buttonSize: isTablet ? 60 : 54,
              isSolid: true,
              tooltip: 'Previous',
              onPressed: onPrevious != null
                  ? () {
                      HapticFeedback.mediumImpact();
                      onPrevious?.call();
                    }
                  : null,
              colorScheme: colorScheme,
            ),

            SizedBox(width: isTablet ? 18 : 14),

            // Play / Pause — largest button
            _PlayPauseButton(
              isPlaying: isPlaying,
              onPressed: () {
                HapticFeedback.mediumImpact();
                if (isPlaying) {
                  player.pause();
                } else {
                  player.play();
                }
              },
              colorScheme: colorScheme,
              isTablet: isTablet,
            ),

            SizedBox(width: isTablet ? 18 : 14),

            // Next
            _CircleControlButton(
              icon: Icons.skip_next_rounded,
              iconSize: isTablet ? 36 : 30,
              buttonSize: isTablet ? 60 : 54,
              isSolid: true,
              tooltip: 'Next',
              onPressed: onNext != null
                  ? () {
                      HapticFeedback.mediumImpact();
                      onNext?.call();
                    }
                  : null,
              colorScheme: colorScheme,
            ),

            SizedBox(width: isTablet ? 16 : 12),

            // Fast forward (10s ahead)
            _CircleControlButton(
              icon: Icons.fast_forward_rounded,
              iconSize: isTablet ? 30 : 26,
              buttonSize: isTablet ? 52 : 46,
              isSolid: false,
              tooltip: 'Forward 10s',
              onPressed: () {
                HapticFeedback.lightImpact();
                final pos = player.position.value;
                final dur = player.duration.value;
                final newPos = pos + const Duration(seconds: 10);
                player.seek(newPos > dur ? dur : newPos);
              },
              colorScheme: colorScheme,
            ),
          ],
        );
      },
    );
  }
}

/// A circle button used for rewind, previous, next, forward.
class _CircleControlButton extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final double buttonSize;
  final bool isSolid;
  final String? tooltip;
  final VoidCallback? onPressed;
  final ColorScheme colorScheme;

  const _CircleControlButton({
    required this.icon,
    required this.iconSize,
    required this.buttonSize,
    required this.isSolid,
    this.tooltip,
    required this.onPressed,
    required this.colorScheme,
  });

  @override
  State<_CircleControlButton> createState() => _CircleControlButtonState();
}

class _CircleControlButtonState extends State<_CircleControlButton>
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
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.88,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onPressed != null) {
      _controller.forward().then((_) => _controller.reverse());
      widget.onPressed!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final button = AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTap: _handleTap,
            child: Container(
              width: widget.buttonSize,
              height: widget.buttonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isSolid
                    ? Colors.black
                    : Colors.white.withOpacity(0.1),
                boxShadow: widget.isSolid
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                widget.icon,
                size: widget.iconSize,
                color: widget.onPressed != null
                    ? Colors.white
                    : Colors.white.withOpacity(0.3),
              ),
            ),
          ),
        );
      },
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: button);
    }
    return button;
  }
}

/// The main play/pause button — largest, solid black.
class _PlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onPressed;
  final ColorScheme colorScheme;
  final bool isTablet;

  const _PlayPauseButton({
    required this.isPlaying,
    required this.onPressed,
    required this.colorScheme,
    this.isTablet = false,
  });

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton>
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
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
    final buttonSize = widget.isTablet ? 90.0 : 80.0;
    final iconSize = widget.isTablet ? 48.0 : 42.0;

    return Tooltip(
      message: widget.isPlaying ? 'Pause' : 'Play',
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black, // Match demo pure black
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 16,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: Icon(
                    widget.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    key: ValueKey(widget.isPlaying),
                    size: iconSize,
                    color: Colors.white, // Match demo pure white icon
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
