import 'package:flutter/material.dart';

class LibraryFilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final IconData? icon;
  final bool isAddButton;

  const LibraryFilterChip({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.icon,
    this.isAddButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isActive && !isAddButton
              ? LinearGradient(
                  colors: [
                    colorScheme.primary,
                    colorScheme.primary.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isAddButton
              ? Colors.transparent
              : (isActive ? null : colorScheme.surfaceVariant.withOpacity(0.3)),
          border: Border.all(
            color: isAddButton
                ? colorScheme.primary
                : (isActive ? Colors.transparent : colorScheme.outline.withOpacity(0.5)),
            width: isAddButton ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isActive && !isAddButton
                    ? colorScheme.onPrimary
                    : (isAddButton ? colorScheme.primary : colorScheme.onSurface),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive && !isAddButton
                    ? colorScheme.onPrimary
                    : (isAddButton ? colorScheme.primary : colorScheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
