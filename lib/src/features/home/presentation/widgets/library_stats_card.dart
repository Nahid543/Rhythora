import 'package:flutter/material.dart';

class LibraryStatsCard extends StatefulWidget {
  final int songCount;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final bool isTablet;
  final Duration? todayListeningTime;
  final int? todaySongPlays;

  const LibraryStatsCard({
    super.key,
    required this.songCount,
    required this.colorScheme,
    required this.textTheme,
    required this.isTablet,
    this.todayListeningTime,
    this.todaySongPlays,
  });

  @override
  State<LibraryStatsCard> createState() => _LibraryStatsCardState();
}

class _LibraryStatsCardState extends State<LibraryStatsCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return '< 1m';
    }
  }

  @override
  Widget build(BuildContext context) {
    final listeningTime = widget.todayListeningTime ?? Duration.zero;
    final songPlays = widget.todaySongPlays ?? 0;
    final totalSongs = widget.songCount;
    final hasActivity = songPlays > 0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * value),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(widget.isTablet ? 24 : 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              widget.colorScheme.primaryContainer.withOpacity(0.6),
              widget.colorScheme.secondaryContainer.withOpacity(0.3),
              widget.colorScheme.tertiaryContainer.withOpacity(0.2),
            ],
          ),
          border: Border.all(
            color: widget.colorScheme.outline.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.colorScheme.primary.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.colorScheme.primary,
                        widget.colorScheme.secondary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: widget.colorScheme.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.insights_rounded,
                    color: widget.colorScheme.onPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Today\'s Activity',
                  style: widget.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: widget.colorScheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                        return Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasActivity
                                ? Colors.green
                                : widget.colorScheme.outline,
                            boxShadow: hasActivity
                                ? [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(
                                        0.6 * _pulseAnimation.value,
                                  ),
                                  blurRadius: 8 + (4 * _pulseAnimation.value),
                                  spreadRadius: _pulseAnimation.value * 2,
                                ),
                              ]
                            : null,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Stats Grid
            Row(
              children: [
                // Listening Time
                Expanded(
                  child: _ModernStatItem(
                    icon: Icons.access_time_rounded,
                    value: _formatDuration(listeningTime),
                    label: 'Listening time',
                    colorScheme: widget.colorScheme,
                    textTheme: widget.textTheme,
                    gradientColors: [
                      widget.colorScheme.primary,
                      widget.colorScheme.secondary,
                    ],
                    isHighlighted: listeningTime.inMinutes > 0,
                  ),
                ),
                SizedBox(width: widget.isTablet ? 16 : 12),

                // Unique Songs
                Expanded(
                  child: _ModernStatItem(
                    icon: Icons.queue_music_rounded,
                    value: '$songPlays',
                    label: songPlays == 1 ? 'Song played' : 'Songs played',
                    colorScheme: widget.colorScheme,
                    textTheme: widget.textTheme,
                    gradientColors: [
                      widget.colorScheme.tertiary,
                      widget.colorScheme.secondary,
                    ],
                    isHighlighted: hasActivity,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Total Library Info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: widget.colorScheme.surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.colorScheme.outline.withOpacity(0.1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.library_music_rounded,
                    size: 16,
                    color: widget.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$totalSongs songs in your library',
                    style: widget.textTheme.bodySmall?.copyWith(
                      color: widget.colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModernStatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final List<Color> gradientColors;
  final bool isHighlighted;

  const _ModernStatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.colorScheme,
    required this.textTheme,
    required this.gradientColors,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted
              ? gradientColors[0].withOpacity(0.3)
              : colorScheme.outline.withOpacity(0.1),
          width: 1.5,
        ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: gradientColors[0].withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradientColors),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (context, animValue, child) {
              return ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: isHighlighted
                      ? gradientColors
                      : [
                          colorScheme.onSurface,
                          colorScheme.onSurface,
                        ],
                ).createShader(bounds),
                child: Text(
                  value,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.6),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
