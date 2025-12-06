// lib/src/features/playback/presentation/widgets/now_playing_actions_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../library/domain/entities/song.dart';
import '../../../library/domain/entities/playlist.dart';
import '../../../library/data/playlist_repository.dart';

class NowPlayingActionsSheet extends StatelessWidget {
  final Song song;

  const NowPlayingActionsSheet({
    super.key,
    required this.song,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final repo = PlaylistRepository.instance;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary,
                          colorScheme.secondary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.settings_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Song Options',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const Divider(height: 1),

            // Add to Playlist (TOP PRIORITY)
            ValueListenableBuilder<List<Playlist>>(
              valueListenable: repo.playlistsNotifier,
              builder: (context, playlists, _) {
                return _ActionTile(
                  icon: Icons.playlist_add_rounded,
                  iconColor: colorScheme.primary,
                  title: 'Add to Playlist',
                  subtitle: playlists.isEmpty 
                      ? 'Create your first playlist'
                      : '${playlists.length} ${playlists.length == 1 ? "playlist" : "playlists"}',
                  badge: playlists.isEmpty ? 'New' : null,
                  onTap: () {
                    Navigator.pop(context);
                    _showPlaylistSelector(context, song, playlists);
                  },
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                );
              },
            ),

            // Song Info
            _ActionTile(
              icon: Icons.info_outline_rounded,
              iconColor: colorScheme.tertiary,
              title: 'Song Information',
              subtitle: 'View details',
              onTap: () {
                Navigator.pop(context);
                _showSongInfoDialog(context, song);
              },
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),

            // Share (with description)
            _ActionTile(
              icon: Icons.share_rounded,
              iconColor: colorScheme.secondary,
              title: 'Share Song',
              subtitle: 'Copy song info',
              onTap: () {
                Navigator.pop(context);
                _shareSong(context, song);
              },
              colorScheme: colorScheme,
              textTheme: textTheme,
              showDivider: false,
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showPlaylistSelector(
    BuildContext context,
    Song song,
    List<Playlist> playlists,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final repo = PlaylistRepository.instance;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Icon(Icons.playlist_add_rounded, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        'Add to Playlist',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Create New Playlist
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _showCreatePlaylistDialog(context, song);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primaryContainer.withOpacity(0.5),
                              colorScheme.secondaryContainer.withOpacity(0.5),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.primary.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.add_rounded,
                                color: colorScheme.onPrimary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Create New Playlist',
                                    style: textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Start a fresh collection',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 18,
                              color: colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Existing Playlists
                if (playlists.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.playlist_add_check_rounded,
                            size: 64,
                            color: colorScheme.primary.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No playlists yet',
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create one to get started',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: playlists.length,
                      itemBuilder: (context, index) {
                        final playlist = playlists[index];
                        final alreadyAdded = playlist.songIds.contains(song.id);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: alreadyAdded
                                  ? null
                                  : () {
                                      repo.addSongToPlaylist(playlist.id, song.id);
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text('Added to "${playlist.name}"'),
                                              ),
                                            ],
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                          backgroundColor: colorScheme.primary,
                                        ),
                                      );
                                    },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: alreadyAdded
                                      ? colorScheme.surfaceVariant.withOpacity(0.5)
                                      : colorScheme.surfaceVariant.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: alreadyAdded
                                        ? colorScheme.primary.withOpacity(0.5)
                                        : colorScheme.outline.withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.playlist_play_rounded,
                                        color: colorScheme.onPrimaryContainer,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            playlist.name,
                                            style: textTheme.bodyLarge?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${playlist.songCount} ${playlist.songCount == 1 ? "song" : "songs"}',
                                            style: textTheme.bodySmall?.copyWith(
                                              color: colorScheme.onSurface.withOpacity(0.6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (alreadyAdded)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primary.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check,
                                              size: 16,
                                              color: colorScheme.primary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Added',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: colorScheme.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      Icon(
                                        Icons.add_circle_outline,
                                        color: colorScheme.primary,
                                        size: 22,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, Song song) {
    final controller = TextEditingController();
    final repo = PlaylistRepository.instance;
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.playlist_add_rounded,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Create Playlist'),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 50,
          decoration: InputDecoration(
            hintText: 'My Awesome Playlist',
            labelText: 'Playlist Name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            prefixIcon: const Icon(Icons.edit_rounded),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final playlist = await repo.createPlaylist(name);
                await repo.addSongToPlaylist(playlist.id, song.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✓ Created "$name" with this song'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: colorScheme.primary,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showSongInfoDialog(BuildContext context, Song song) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    String formatDuration(Duration d) {
      final m = d.inMinutes;
      final s = (d.inSeconds % 60).toString().padLeft(2, '0');
      return '$m:$s';
    }

    // ← FIXED: Better artist handling
    String getArtist() {
      if (song.artist.isEmpty || song.artist == '<unknown>') {
        return 'Unknown Artist';
      }
      return song.artist;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.primary, colorScheme.secondary],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.info_outline_rounded,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Song Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow('Title', song.title, textTheme, colorScheme),
              const SizedBox(height: 16),
              _InfoRow('Artist', getArtist(), textTheme, colorScheme),
              if (song.album.isNotEmpty) ...[
                const SizedBox(height: 16),
                _InfoRow('Album', song.album, textTheme, colorScheme),
              ],
              const SizedBox(height: 16),
              _InfoRow('Duration', formatDuration(song.duration), textTheme, colorScheme),
            ],
          ),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.check),
            label: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _shareSong(BuildContext context, Song song) {
    final artist = song.artist.isEmpty || song.artist == '<unknown>' 
        ? 'Unknown Artist' 
        : song.artist;
    final shareText = '♪ ${song.title} - $artist';
    
    Clipboard.setData(ClipboardData(text: shareText));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            const Expanded(child: Text('Song info copied!')),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// Action Tile Widget
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String? badge;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final bool showDivider;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.badge,
    required this.onTap,
    required this.colorScheme,
    required this.textTheme,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: iconColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                style: textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (badge != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  badge!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: colorScheme.onSurface.withOpacity(0.4),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 72,
            endIndent: 20,
            color: colorScheme.outlineVariant.withOpacity(0.5),
          ),
      ],
    );
  }
}

// Info Row Widget (Enhanced)
Widget _InfoRow(String label, String value, TextTheme textTheme, ColorScheme colorScheme) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: colorScheme.surfaceVariant.withOpacity(0.5),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}
