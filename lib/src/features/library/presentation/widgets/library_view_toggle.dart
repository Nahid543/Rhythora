import 'package:flutter/material.dart';

enum LibraryViewType { list, grid }

class LibraryViewToggle extends StatelessWidget {
  final LibraryViewType currentView;
  final Function(LibraryViewType) onViewChanged;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const LibraryViewToggle({
    super.key,
    required this.currentView,
    required this.onViewChanged,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleButton(
            icon: Icons.view_list_rounded,
            isSelected: currentView == LibraryViewType.list,
            onTap: () => onViewChanged(LibraryViewType.list),
            colorScheme: colorScheme,
          ),
          const SizedBox(width: 4),
          _ToggleButton(
            icon: Icons.grid_view_rounded,
            isSelected: currentView == LibraryViewType.grid,
            onTap: () => onViewChanged(LibraryViewType.grid),
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _ToggleButton({
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isSelected
                ? colorScheme.onPrimary
                : colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ),
    );
  }
}
