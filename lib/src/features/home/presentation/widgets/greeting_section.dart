import 'package:flutter/material.dart';

class GreetingSection extends StatelessWidget {
  final String greeting;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  const GreetingSection({
    super.key,
    required this.greeting,
    required this.textTheme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              greeting,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              _getGreetingIcon(),
              color: colorScheme.primary,
              size: 28,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Dive back into your offline library.',
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.65),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  IconData _getGreetingIcon() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return Icons.wb_sunny_rounded;
    if (hour >= 12 && hour < 18) return Icons.wb_cloudy_rounded;
    if (hour >= 18 && hour < 23) return Icons.nights_stay_rounded;
    return Icons.bedtime_rounded;
  }
}
