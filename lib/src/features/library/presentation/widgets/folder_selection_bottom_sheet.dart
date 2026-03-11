import 'package:flutter/material.dart';
import '../../domain/entities/music_folder.dart';
import '../../domain/models/library_source_settings.dart';

class FolderSelectionBottomSheet extends StatelessWidget {
  final LibrarySourceSettings currentSettings;
  final List<MusicFolder> availableFolders;
  final Function(LibrarySourceSettings) onSettingsChanged;
  final VoidCallback onManageFolders;

  const FolderSelectionBottomSheet({
    super.key,
    required this.currentSettings,
    required this.availableFolders,
    required this.onSettingsChanged,
    required this.onManageFolders,
  });

  String _getFolderDisplayName(String path) {
    if (path.isEmpty) return 'Unknown';
    final segments = path.split('/')..removeWhere((e) => e.trim().isEmpty);
    return segments.isNotEmpty ? segments.last : path;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      padding: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Icon(Icons.folder_shared_rounded, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    'Select Source',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.settings_rounded, color: colorScheme.primary, size: 20),
                    onPressed: () {
                      Navigator.pop(context);
                      onManageFolders();
                    },
                    tooltip: 'Manage Folders',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            
            // List
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                physics: const BouncingScrollPhysics(),
                children: [
                  // All Music Option
                  _FolderOptionTile(
                    title: 'All Music',
                    subtitle: 'Library wide',
                    icon: Icons.library_music_rounded,
                    isSelected: currentSettings.isAllMusic,
                    onTap: () {
                      if (!currentSettings.isAllMusic) {
                        onSettingsChanged(currentSettings.activateAllMusic());
                      }
                      Navigator.pop(context);
                    },
                  ),
                  
                  if (availableFolders.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                      child: Text(
                        'FOLDERS',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),

                  ...availableFolders.map((folder) {
                    final isSelected = currentSettings.isFolderActive(folder.path);
                    return _FolderOptionTile(
                      title: _getFolderDisplayName(folder.path),
                      subtitle: '${folder.songCount} songs',
                      icon: Icons.folder_rounded,
                      isSelected: isSelected,
                      onTap: () {
                        onSettingsChanged(currentSettings.toggleFolder(folder.path));
                        // Don't auto-pop for individual folders, they might want to select multiple
                      },
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _FolderOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FolderOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected 
              ? colorScheme.primary.withValues(alpha: 0.15) 
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.8), // Increased visibility
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: isSelected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.85), // Increased visibility
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: textTheme.bodyLarge?.copyWith(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? colorScheme.primary : colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.7), // Increased visibility
          fontSize: 13,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
          : const SizedBox.shrink(),
      onTap: onTap,
    );
  }
}
