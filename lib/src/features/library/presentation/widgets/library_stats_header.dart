import 'package:flutter/material.dart';

class LibraryStatsHeader extends StatelessWidget {
  final int songCount;
  final Duration totalDuration;
  final int artistCount;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const LibraryStatsHeader({
    super.key,
    required this.songCount,
    required this.totalDuration,
    required this.artistCount,
    required this.colorScheme,
    required this.textTheme,
  });

  String _formatTotalDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withOpacity(0.3),
            colorScheme.secondaryContainer.withOpacity(0.2),
          ],
        ),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            icon: Icons.library_music_rounded,
            value: '$songCount',
            label: 'Songs',
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
          Container(
            width: 1,
            height: 32,
            color: colorScheme.outline.withOpacity(0.3),
          ),
          _StatItem(
            icon: Icons.schedule_rounded,
            value: _formatTotalDuration(totalDuration),
            label: 'Duration',
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
          Container(
            width: 1,
            height: 32,
            color: colorScheme.outline.withOpacity(0.3),
          ),
          _StatItem(
            icon: Icons.person_rounded,
            value: '$artistCount',
            label: 'Artists',
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: colorScheme.primary, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}
