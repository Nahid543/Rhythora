import 'package:flutter/material.dart';
import '../../domain/entities/music_folder.dart';
import '../../domain/models/library_source_settings.dart';
import 'folder_selection_bottom_sheet.dart';

class LibraryFilterBar extends StatelessWidget {
  final LibrarySourceSettings currentSettings;
  final List<MusicFolder> availableFolders;
  final Function(LibrarySourceSettings) onSettingsChanged;
  final VoidCallback onManageFolders;

  const LibraryFilterBar({
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

  void _openFolderSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => FolderSelectionBottomSheet(
        currentSettings: currentSettings,
        availableFolders: availableFolders,
        onSettingsChanged: onSettingsChanged,
        onManageFolders: onManageFolders,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Determine the label for the button
    String label = 'All Music';
    if (!currentSettings.isAllMusic && currentSettings.folderPaths.isNotEmpty) {
      if (currentSettings.folderPaths.length == 1) {
        label = _getFolderDisplayName(currentSettings.folderPaths.first);
      } else {
        label = '${currentSettings.folderPaths.length} Folders';
      }
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openFolderSelection(context),
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.folder_rounded,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}