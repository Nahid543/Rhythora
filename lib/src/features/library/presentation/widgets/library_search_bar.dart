import 'package:flutter/material.dart';

class LibrarySearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String searchQuery;
  final VoidCallback onClear;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const LibrarySearchBar({
    super.key,
    required this.controller,
    required this.searchQuery,
    required this.onClear,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        style: textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: 'Search your library...',
          hintStyle: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.5),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: colorScheme.primary,
            size: 24,
          ),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                  onPressed: onClear,
                )
              : null,
          filled: true,
          fillColor: colorScheme.surfaceVariant.withOpacity(0.5),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: colorScheme.primary.withOpacity(0.5),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}
