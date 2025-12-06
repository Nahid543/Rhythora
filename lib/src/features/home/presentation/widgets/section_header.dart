import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final TextTheme textTheme;
  final IconData? icon;
  final Widget? action;

  const SectionHeader({
    super.key,
    required this.title,
    required this.textTheme,
    this.icon,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 24),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        if (action != null) ...[
          const Spacer(),
          action!,
        ],
      ],
    );
  }
}
