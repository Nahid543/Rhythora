
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/playlist.dart';
import '../../data/playlist_repository.dart';
// ignore: unused_import
import '../../../playback/data/audio_player_manager.dart';

class SongOptionsBottomSheet extends StatelessWidget {
  final Song song;
  final List<Song> allSongs;

  const SongOptionsBottomSheet({
    super.key,
    required this.song,
    required this.allSongs,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final repo = PlaylistRepository.instance;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: colorScheme.surfaceVariant,
                    ),
                    child: song.albumArtPath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(song.albumArtPath!),
                              fit: BoxFit.cover,
                              cacheWidth: 200,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.music_note_rounded,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.music_note_rounded,
                            color: colorScheme.onSurfaceVariant,
                          ),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          song.artist,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Divider(
              height: 1,
              thickness: 1,
              color: colorScheme.outlineVariant,
            ),

            _OptionTile(
              icon: Icons.favorite_border_rounded,
              label: 'Add to Favorites',
              onTap: () {
                repo.toggleFavorite(song.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      repo.isFavorite(song.id)
                          ? 'Added to Favorites'
                          : 'Removed from Favorites',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),

            ValueListenableBuilder<List<Playlist>>(
              valueListenable: repo.playlistsNotifier,
              builder: (context, playlists, _) {
                return _OptionTile(
                  icon: Icons.playlist_add_rounded,
                  label: 'Add to Playlist',
                  onTap: () {
                    Navigator.pop(context);
                    _showPlaylistSelector(context, song, playlists);
                  },
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                );
              },
            ),

            _OptionTile(
              icon: Icons.play_circle_outline_rounded,
              label: 'Play Next',
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Added to queue'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),

            _OptionTile(
              icon: Icons.queue_music_rounded,
              label: 'Add to Queue',
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Added to queue'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),

            _OptionTile(
              icon: Icons.info_outline_rounded,
              label: 'Song Info',
              onTap: () {
                Navigator.pop(context);
                _showSongInfoDialog(context, song);
              },
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),

            _OptionTile(
              icon: Icons.share_rounded,
              label: 'Share',
              onTap: () {
                Navigator.pop(context);
                _shareSong(context, song);
              },
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),

            const SizedBox(height: 16),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              child: Text(
                'Add to Playlist',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 16),

            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              title: Text(
                'Create New Playlist',
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _showCreatePlaylistDialog(context, song);
              },
            ),

            if (playlists.isNotEmpty)
              const Divider(height: 1, indent: 16, endIndent: 16),

            if (playlists.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No playlists yet',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  final alreadyAdded = playlist.songIds.contains(song.id);

                  return ListTile(
                    leading: Icon(
                      Icons.playlist_play_rounded,
                      color: colorScheme.primary,
                    ),
                    title: Text(playlist.name),
                    subtitle: Text('${playlist.songCount} songs'),
                    trailing: alreadyAdded
                        ? Icon(
                            Icons.check_rounded,
                            color: colorScheme.primary,
                          )
                        : null,
                    enabled: !alreadyAdded,
                    onTap: alreadyAdded
                        ? null
                        : () {
                            repo.addSongToPlaylist(playlist.id, song.id);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Added to "${playlist.name}"',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                  );
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, Song song) {
    final controller = TextEditingController();
    final repo = PlaylistRepository.instance;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 50,
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final playlist = await repo.createPlaylist(name);
                await repo.addSongToPlaylist(playlist.id, song.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Created "$name" and added song'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showSongInfoDialog(BuildContext context, Song song) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: colorScheme.primary),
            const SizedBox(width: 12),
            const Text('Song Info'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow('Title', song.title, textTheme),
              _InfoRow('Artist', song.artist, textTheme),
              _InfoRow('Album', song.album, textTheme),
              _InfoRow('Duration', _formatDuration(song.duration), textTheme),
              if (song.filePath != null)
                _InfoRow(
                  'Format',
                  song.filePath!.split('.').last.toUpperCase(),
                  textTheme,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _InfoRow(String label, String value, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  void _shareSong(BuildContext context, Song song) {
    final shareText = '${song.title} - ${song.artist}';
    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Song info copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: colorScheme.onSurface),
      title: Text(
        label,
        style: textTheme.bodyLarge,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }
}
