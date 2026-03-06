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
          color: isActive && !isAddButton
              ? colorScheme.primary // Elegant solid Indigo
              : Colors.transparent, // Blends into pitch black background
          border: Border.all(
            color: isAddButton
                ? colorScheme.primary
                : (isActive ? Colors.transparent : colorScheme.outline.withValues(alpha: 0.3)), // Subtle inactive outline
            width: isAddButton ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(999), // Perfect pill shape
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isActive && !isAddButton
                    ? Colors.white
                    : (isAddButton ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.7)),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive && !isAddButton
                    ? Colors.white
                    : (isAddButton ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.7)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
