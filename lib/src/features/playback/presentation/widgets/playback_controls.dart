// lib/src/features/playback/presentation/widgets/playback_controls.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/audio_player_manager.dart';
import '../../domain/repeat_mode.dart';

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
          children: [
            // Shuffle
            ValueListenableBuilder<bool>(
              valueListenable: player.isShuffleEnabled,
              builder: (context, isShuffleEnabled, __) {
                return _ControlButton(
                  icon: Icons.shuffle_rounded,
                  isActive: isShuffleEnabled,
                  tooltip: isShuffleEnabled ? 'Shuffle On' : 'Shuffle Off',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    player.toggleShuffle();
                  },
                  colorScheme: colorScheme,
                  isTablet: isTablet,
                );
              },
            ),

            SizedBox(width: isTablet ? 20 : 16),

            // Previous
            _ControlButton(
              icon: Icons.skip_previous_rounded,
              size: isTablet ? 44 : 40,
              tooltip: 'Previous',
              onPressed: onPrevious != null
                  ? () {
                      HapticFeedback.mediumImpact();
                      onPrevious?.call();
                    }
                  : null,
              colorScheme: colorScheme,
              isTablet: isTablet,
            ),

            SizedBox(width: isTablet ? 24 : 20),

            // Play/Pause (Main button)
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

            SizedBox(width: isTablet ? 24 : 20),

            // Next
            _ControlButton(
              icon: Icons.skip_next_rounded,
              size: isTablet ? 44 : 40,
              tooltip: 'Next',
              onPressed: onNext != null
                  ? () {
                      HapticFeedback.mediumImpact();
                      onNext?.call();
                    }
                  : null,
              colorScheme: colorScheme,
              isTablet: isTablet,
            ),

            SizedBox(width: isTablet ? 20 : 16),

            // Repeat
            ValueListenableBuilder<RepeatMode>(
              valueListenable: player.repeatMode,
              builder: (context, repeatMode, _) {
                return _ControlButton(
                  icon: _getRepeatIcon(repeatMode),
                  isActive: repeatMode != RepeatMode.off,
                  tooltip: _getRepeatTooltip(repeatMode),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    player.toggleRepeatMode();
                  },
                  colorScheme: colorScheme,
                  badge: repeatMode == RepeatMode.one ? '1' : null,
                  isTablet: isTablet,
                );
              },
            ),
          ],
        );
      },
    );
  }

  IconData _getRepeatIcon(RepeatMode mode) {
    switch (mode) {
      case RepeatMode.off:
        return Icons.repeat_rounded;
      case RepeatMode.all:
        return Icons.repeat_rounded;
      case RepeatMode.one:
        return Icons.repeat_one_rounded;
    }
  }

  String _getRepeatTooltip(RepeatMode mode) {
    switch (mode) {
      case RepeatMode.off:
        return 'Repeat Off';
      case RepeatMode.all:
        return 'Repeat All';
      case RepeatMode.one:
        return 'Repeat One';
    }
  }
}

// Control Button
class _ControlButton extends StatefulWidget {
  final IconData icon;
  final bool isActive;
  final String? tooltip;
  final VoidCallback? onPressed;
  final double size;
  final ColorScheme colorScheme;
  final String? badge;
  final bool isTablet;

  const _ControlButton({
    required this.icon,
    this.isActive = false,
    this.tooltip,
    required this.onPressed,
    this.size = 28,
    required this.colorScheme,
    this.badge,
    this.isTablet = false,
  });

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton>
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
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _handleTap,
              borderRadius: BorderRadius.circular(50),
              child: Container(
                padding: EdgeInsets.all(widget.isTablet ? 10 : 8),
                decoration: widget.isActive
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.colorScheme.primaryContainer.withOpacity(
                          0.3,
                        ),
                      )
                    : null,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      widget.icon,
                      size: widget.size,
                      color: widget.isActive
                          ? widget.colorScheme.primary
                          : widget.onPressed != null
                          ? widget.colorScheme.onSurface.withOpacity(0.8)
                          : widget.colorScheme.onSurface.withOpacity(0.3),
                    ),
                    if (widget.badge != null)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: widget.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 14,
                            minHeight: 14,
                          ),
                          child: Text(
                            widget.badge!,
                            style: TextStyle(
                              color: widget.colorScheme.onPrimary,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
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

// Enhanced Play/Pause Button
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
    final buttonSize = widget.isTablet ? 80.0 : 72.0;
    final iconSize = widget.isTablet ? 44.0 : 40.0;

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
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.colorScheme.primary,
                      widget.colorScheme.secondary,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.colorScheme.primary.withOpacity(0.4),
                      blurRadius: 24,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: widget.colorScheme.secondary.withOpacity(0.2),
                      blurRadius: 16,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
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
                    color: Colors.white,
                    shadows: const [
                      Shadow(color: Colors.black26, blurRadius: 4),
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
