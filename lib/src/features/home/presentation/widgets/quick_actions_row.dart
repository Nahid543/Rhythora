import 'package:flutter/material.dart';

import '../../../library/domain/entities/song.dart';

class QuickActionsRow extends StatelessWidget {
  final Song? currentSong;
  final VoidCallback onOpenLibrary;
  final VoidCallback onOpenQueue;
  final VoidCallback onOpenNowPlaying;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final bool isTablet;

  const QuickActionsRow({
    super.key,
    required this.currentSong,
    required this.onOpenLibrary,
    required this.onOpenQueue,
    required this.onOpenNowPlaying,
    required this.colorScheme,
    required this.textTheme,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: QuickActionButton(
            icon: Icons.library_music_rounded,
            label: 'Library',
            onTap: onOpenLibrary,
            colorScheme: colorScheme,
            textTheme: textTheme,
            isTablet: isTablet,
            delay: 0,
          ),
        ),
        SizedBox(width: isTablet ? 16 : 12),
        Expanded(
          child: QuickActionButton(
            icon: Icons.queue_music_rounded,
            label: 'Queue',
            onTap: onOpenQueue,
            colorScheme: colorScheme,
            textTheme: textTheme,
            isTablet: isTablet,
            delay: 100,
          ),
        ),
        SizedBox(width: isTablet ? 16 : 12),
        Expanded(
          child: QuickActionButton(
            icon: Icons.play_circle_rounded,
            label: 'Now playing',
            onTap: currentSong != null ? onOpenNowPlaying : null,
            colorScheme: colorScheme,
            textTheme: textTheme,
            isTablet: isTablet,
            delay: 200,
          ),
        ),
      ],
    );
  }
}

class QuickActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final bool isTablet;
  final int delay;

  const QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    required this.colorScheme,
    required this.textTheme,
    required this.isTablet,
    this.delay = 0,
  });

  @override
  State<QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<QuickActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(20),
            child: Ink(
              padding: EdgeInsets.symmetric(
                horizontal: widget.isTablet ? 16 : 12,
                vertical: widget.isTablet ? 18 : 14,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: enabled
                    ? widget.colorScheme.surfaceVariant.withOpacity(0.6)
                    : widget.colorScheme.surfaceVariant.withOpacity(0.2),
                border: Border.all(
                  color: enabled
                      ? widget.colorScheme.outline.withOpacity(0.3)
                      : widget.colorScheme.outline.withOpacity(0.1),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.icon,
                    size: widget.isTablet ? 28 : 24,
                    color: enabled
                        ? widget.colorScheme.primary
                        : widget.colorScheme.onSurface.withOpacity(0.3),
                  ),
                  SizedBox(height: widget.isTablet ? 10 : 8),
                  Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: widget.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: enabled
                          ? widget.colorScheme.onSurface
                          : widget.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
