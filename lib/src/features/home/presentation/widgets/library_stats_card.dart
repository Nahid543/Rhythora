import 'dart:ui';
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
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOutSine,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(widget.isTablet ? 24 : 18),
      decoration: BoxDecoration(
        color: isDark ? widget.colorScheme.surfaceContainerHigh : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.colorScheme.outline.withOpacity(isDark ? 0.15 : 0.08),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.colorScheme.primary.withOpacity(0.8),
                      widget.colorScheme.secondary.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.auto_graph_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Today\'s Activity',
                style: widget.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: widget.colorScheme.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              // Sync Indicator
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: hasActivity
                          ? Colors.green.withOpacity(0.15)
                          : widget.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasActivity
                            ? Colors.green.withOpacity(0.3 * _pulseAnimation.value)
                            : widget.colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasActivity ? Colors.green : widget.colorScheme.onSurfaceVariant,
                            boxShadow: hasActivity
                                ? [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.8 * _pulseAnimation.value),
                                      blurRadius: 6 * _pulseAnimation.value,
                                      spreadRadius: 2 * _pulseAnimation.value,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          hasActivity ? 'Active Sync' : 'Synced',
                          style: widget.textTheme.labelSmall?.copyWith(
                            color: hasActivity ? Colors.green.shade600 : widget.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _PremiumStatItem(
                  icon: Icons.access_time_rounded,
                  value: _formatDuration(listeningTime),
                  label: 'Listening time',
                  colorScheme: widget.colorScheme,
                  textTheme: widget.textTheme,
                  isHighlighted: listeningTime.inMinutes > 0,
                ),
              ),
              SizedBox(width: widget.isTablet ? 16 : 12),
              Expanded(
                child: _PremiumStatItem(
                  icon: Icons.queue_music_rounded,
                  value: '$songPlays',
                  label: songPlays == 1 ? 'Song played' : 'Songs played',
                  colorScheme: widget.colorScheme,
                  textTheme: widget.textTheme,
                  isHighlighted: hasActivity,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Total Library Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? widget.colorScheme.surfaceContainerHighest : widget.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.colorScheme.outline.withOpacity(0.05),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.library_music_rounded,
                  size: 18,
                  color: widget.colorScheme.primary.withOpacity(0.8),
                ),
                const SizedBox(width: 8),
                Text(
                  '$totalSongs total tracks in offline library',
                  style: widget.textTheme.bodySmall?.copyWith(
                    color: widget.colorScheme.onSurface.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumStatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final bool isHighlighted;

  const _PremiumStatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.colorScheme,
    required this.textTheme,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHighest.withOpacity(0.5) : colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlighted
              ? colorScheme.primary.withOpacity(isDark ? 0.3 : 0.4)
              : colorScheme.outline.withOpacity(0.1),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: isHighlighted ? colorScheme.primary : colorScheme.onSurfaceVariant,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            // Re-render immediately when value changes so sync is flawless
            key: ValueKey(value),
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: isHighlighted ? colorScheme.primary : colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}
