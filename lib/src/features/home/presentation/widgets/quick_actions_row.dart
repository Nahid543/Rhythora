import 'dart:ui';
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
        // Make the Library button slightly more prominent as requested
        Expanded(
          flex: 12,
          child: QuickActionButton(
            icon: Icons.library_music_rounded,
            label: 'Library',
            onTap: onOpenLibrary,
            colorScheme: colorScheme,
            textTheme: textTheme,
            isTablet: isTablet,
            delay: 0,
            isPrimary: true,
          ),
        ),
        SizedBox(width: isTablet ? 16 : 12),
        Expanded(
          flex: 10,
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
          flex: 10,
          child: QuickActionButton(
            icon: Icons.play_circle_rounded,
            label: 'Playing',
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
  final bool isPrimary;

  const QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    required this.colorScheme,
    required this.textTheme,
    required this.isTablet,
    this.delay = 0,
    this.isPrimary = false,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: widget.isTablet ? 16 : 8,
                vertical: widget.isTablet ? 20 : 16,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: widget.isPrimary && enabled
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          widget.colorScheme.primary.withOpacity(isDark ? 0.8 : 0.15),
                          widget.colorScheme.secondary.withOpacity(isDark ? 0.6 : 0.05),
                        ],
                      )
                    : LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: enabled
                            ? [
                                widget.colorScheme.surfaceVariant.withOpacity(0.8),
                                widget.colorScheme.surfaceVariant.withOpacity(0.4),
                              ]
                            : [
                                widget.colorScheme.surfaceVariant.withOpacity(0.3),
                                widget.colorScheme.surfaceVariant.withOpacity(0.1),
                              ],
                      ),
                border: Border.all(
                  color: widget.isPrimary && enabled
                      ? widget.colorScheme.primary.withOpacity(0.5)
                      : enabled
                          ? widget.colorScheme.outline.withOpacity(0.2)
                          : widget.colorScheme.outline.withOpacity(0.05),
                  width: widget.isPrimary && enabled ? 1.5 : 1.0,
                ),
                boxShadow: widget.isPrimary && enabled
                    ? [
                        BoxShadow(
                          color: widget.colorScheme.primary.withOpacity(0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: enabled
                              ? (widget.isPrimary
                                  ? (isDark ? Colors.white : widget.colorScheme.primary).withOpacity(0.2)
                                  : widget.colorScheme.primary.withOpacity(0.1))
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.icon,
                          size: widget.isTablet ? 32 : 26,
                          color: enabled
                              ? (widget.isPrimary && !isDark 
                                  ? widget.colorScheme.primary 
                                  : (widget.isPrimary ? Colors.white : widget.colorScheme.primary))
                              : widget.colorScheme.onSurface.withOpacity(0.3),
                        ),
                      ),
                      SizedBox(height: widget.isTablet ? 12 : 10),
                      Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: widget.textTheme.labelMedium?.copyWith(
                          fontWeight: widget.isPrimary ? FontWeight.w800 : FontWeight.w600,
                          letterSpacing: 0.3,
                          color: enabled
                              ? (widget.isPrimary && isDark ? Colors.white : widget.colorScheme.onSurface)
                              : widget.colorScheme.onSurface.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
