import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/local_music_loader.dart';
import '../../domain/entities/music_folder.dart';
import '../../domain/models/library_source_settings.dart';

class ManageMusicFoldersScreen extends StatefulWidget {
  final LibrarySourceSettings currentSettings;

  const ManageMusicFoldersScreen({
    super.key,
    required this.currentSettings,
  });

  @override
  State<ManageMusicFoldersScreen> createState() =>
      _ManageMusicFoldersScreenState();
}

class _ManageMusicFoldersScreenState extends State<ManageMusicFoldersScreen> {
  late LibrarySourceSettings _workingSettings;
  List<MusicFolder>? _folders;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _workingSettings = widget.currentSettings;
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    try {
      final folders = await LocalMusicLoader.instance.loadAvailableFolders();
      if (mounted) {
        setState(() {
          _folders = folders;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading folders: $e');
      if (mounted) {
        setState(() {
          _folders = [];
          _isLoading = false;
        });
      }
    }
  }

  void _toggleFolder(String folderPath) {
    HapticFeedback.lightImpact();
    setState(() {
      _workingSettings = _workingSettings.toggleFolder(folderPath);
    });
  }

  void _toggleVisibility(String folderPath) {
    HapticFeedback.lightImpact();
    setState(() {
      _workingSettings = _workingSettings.toggleFolderVisibility(folderPath);
    });
  }

  void _selectAll() {
    if (_folders == null || _folders!.isEmpty) return;
    
    HapticFeedback.mediumImpact();
    setState(() {
      var updated = _workingSettings;
      for (final folder in _folders!) {
        if (!updated.isFolderActive(folder.path)) {
          updated = updated.toggleFolder(folder.path);
        }
      }
      _workingSettings = updated;
    });
  }

  void _useAllMusic() {
    HapticFeedback.lightImpact();
    setState(() {
      _workingSettings = _workingSettings.activateAllMusic();
    });
    Navigator.pop(context, _workingSettings);
  }

  void _save() {
    HapticFeedback.mediumImpact();
    Navigator.pop(context, _workingSettings);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Music Folders',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (!_isLoading && _folders != null && _folders!.isNotEmpty)
            TextButton(
              onPressed: _selectAll,
              child: const Text('Select All'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.3),
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Select folders to include in your library. Toggle eye icon to hide from filter bar.',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildContent(colorScheme, textTheme),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _useAllMusic,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Use All Music'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    _workingSettings.isAllMusic
                        ? 'Save (All Music)'
                        : 'Save (${_workingSettings.selectedFolderCount} folder${_workingSettings.selectedFolderCount == 1 ? '' : 's'})',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme colorScheme, TextTheme textTheme) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Scanning folders...',
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    if (_folders == null || _folders!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_off_rounded,
              size: 64,
              color: colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No music folders found',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Add music to your device',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _folders!.length,
      itemBuilder: (context, index) {
        final folder = _folders![index];
        final isActive = _workingSettings.isFolderActive(folder.path);
        final isHidden = _workingSettings.isFolderHiddenFromFilterBar(folder.path);

        return _FolderTile(
          folder: folder,
          isActive: isActive,
          isHidden: isHidden,
          onToggle: () => _toggleFolder(folder.path),
          onToggleVisibility: () => _toggleVisibility(folder.path),
        );
      },
    );
  }
}

class _FolderTile extends StatelessWidget {
  final MusicFolder folder;
  final bool isActive;
  final bool isHidden;
  final VoidCallback onToggle;
  final VoidCallback onToggleVisibility;

  const _FolderTile({
    required this.folder,
    required this.isActive,
    required this.isHidden,
    required this.onToggle,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? colorScheme.primaryContainer.withOpacity(0.4)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? colorScheme.primary.withOpacity(0.3)
              : colorScheme.outline.withOpacity(0.2),
          width: isActive ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isActive
                ? colorScheme.primary
                : colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.folder_rounded,
            color: isActive ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
            size: 24,
          ),
        ),
        title: Text(
          folder.name,
          style: textTheme.bodyLarge?.copyWith(
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? colorScheme.primary : null,
          ),
        ),
        subtitle: Text(
          '${folder.songCount} song${folder.songCount == 1 ? '' : 's'}',
          style: textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                isHidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: isHidden
                    ? colorScheme.onSurface.withOpacity(0.4)
                    : colorScheme.primary,
              ),
              onPressed: onToggleVisibility,
              tooltip: isHidden ? 'Show in filter bar' : 'Hide from filter bar',
            ),
            const SizedBox(width: 4),
            Checkbox(
              value: isActive,
              onChanged: (_) => onToggle(),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
        onTap: onToggle,
      ),
    );
  }
}
