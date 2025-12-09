import 'package:flutter/material.dart';

class LibraryStatsHeader extends StatelessWidget {
  final int songCount;
  final Duration totalDuration;
  final int artistCount;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final bool isCompact;

  const LibraryStatsHeader({
    super.key,
    required this.songCount,
    required this.totalDuration,
    required this.artistCount,
    required this.colorScheme,
    required this.textTheme,
    this.isCompact = false,
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
    final padding = EdgeInsets.all(isCompact ? 12 : 16);
    final margin = EdgeInsets.symmetric(
      horizontal: isCompact ? 12 : 20,
      vertical: isCompact ? 6 : 8,
    );

    final useWrap = isCompact;
    final iconSize = isCompact ? 18.0 : 20.0;
    final valueStyle = isCompact
        ? textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          )
        : textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          );
    final labelStyle = textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurface.withOpacity(0.7),
      fontSize: isCompact ? 11 : null,
    );

    return Container(
      margin: margin,
      padding: padding,
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
      child: useWrap
          ? Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.spaceAround,
              children: [
                _StatItem(
                  icon: Icons.library_music_rounded,
                  value: '$songCount',
                  label: 'Songs',
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  iconSize: iconSize,
                  valueStyle: valueStyle,
                  labelStyle: labelStyle,
                ),
                _StatItem(
                  icon: Icons.schedule_rounded,
                  value: _formatTotalDuration(totalDuration),
                  label: 'Duration',
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  iconSize: iconSize,
                  valueStyle: valueStyle,
                  labelStyle: labelStyle,
                ),
                _StatItem(
                  icon: Icons.person_rounded,
                  value: '$artistCount',
                  label: 'Artists',
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  iconSize: iconSize,
                  valueStyle: valueStyle,
                  labelStyle: labelStyle,
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  icon: Icons.library_music_rounded,
                  value: '$songCount',
                  label: 'Songs',
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  iconSize: iconSize,
                  valueStyle: valueStyle,
                  labelStyle: labelStyle,
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
                  iconSize: iconSize,
                  valueStyle: valueStyle,
                  labelStyle: labelStyle,
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
                  iconSize: iconSize,
                  valueStyle: valueStyle,
                  labelStyle: labelStyle,
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
  final double iconSize;
  final TextStyle? valueStyle;
  final TextStyle? labelStyle;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.colorScheme,
    required this.textTheme,
    required this.iconSize,
    required this.valueStyle,
    required this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: colorScheme.primary, size: iconSize),
        SizedBox(height: iconSize >= 20 ? 6 : 4),
        Text(
          value,
          style: valueStyle,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: labelStyle,
        ),
      ],
    );
  }
}
