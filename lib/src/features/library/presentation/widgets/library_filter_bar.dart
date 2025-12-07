import 'package:flutter/material.dart';
import '../../domain/entities/music_folder.dart';
import '../../domain/models/library_source_settings.dart';
import 'library_filter_chip.dart';

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

  void _handleAllMusicTap() {
    if (!currentSettings.isAllMusic) {
      onSettingsChanged(currentSettings.activateAllMusic());
    }
  }

  void _handleFolderTap(String folderPath) {
    onSettingsChanged(currentSettings.toggleFolder(folderPath));
  }

  String _getFolderDisplayName(String path) {
    if (path.isEmpty) return 'Unknown';
    
    final segments = path.split('/')
      ..removeWhere((e) => e.trim().isEmpty);
    
    return segments.isNotEmpty ? segments.last : path;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final visibleFolders = availableFolders.where((folder) {
      return !currentSettings.isFolderHiddenFromFilterBar(folder.path);
    }).toList();

    return Container(
      height: 48,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          LibraryFilterChip(
            label: 'All Music',
            icon: Icons.library_music_rounded,
            isActive: currentSettings.isAllMusic,
            onTap: _handleAllMusicTap,
          ),
          const SizedBox(width: 8),

          ...visibleFolders.map((folder) {
            final isActive = currentSettings.isFolderActive(folder.path);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: LibraryFilterChip(
                label: '${_getFolderDisplayName(folder.path)} (${folder.songCount})',
                icon: Icons.folder_rounded,
                isActive: isActive,
                onTap: () => _handleFolderTap(folder.path),
              ),
            );
          }),

          LibraryFilterChip(
            label: 'Manage',
            icon: Icons.settings_rounded,
            isActive: false,
            isAddButton: true,
            onTap: onManageFolders,
          ),
        ],
      ),
    );
  }
}
