import 'dart:io';
import 'package:flutter/material.dart';
import '../../../domain/entities/song.dart';
import '../../../domain/entities/playlist.dart';
import '../../../data/playlist_repository.dart';
import '../../screens/playlist_detail_screen.dart';

class PlaylistsTab extends StatefulWidget {
  final List<Song> allSongs;
  final Function(Song, List<Song>, int) onSongSelected;

  const PlaylistsTab({
    super.key,
    required this.allSongs,
    required this.onSongSelected,
  });

  @override
  State<PlaylistsTab> createState() => _PlaylistsTabState();
}

class _PlaylistsTabState extends State<PlaylistsTab>
    with AutomaticKeepAliveClientMixin {
  final PlaylistRepository _repo = PlaylistRepository.instance;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ValueListenableBuilder<List<Playlist>>(
      valueListenable: _repo.playlistsNotifier,
      builder: (context, playlists, _) {
        final favoritesPlaylist = _repo.getFavoritesAsPlaylist();
        final allPlaylists = [favoritesPlaylist, ...playlists];

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: _CreatePlaylistButton(
                onPressed: () => _showCreatePlaylistDialog(context),
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
            ),

            Expanded(
              child: allPlaylists.isEmpty
                  ? _buildEmptyState(colorScheme, textTheme)
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: allPlaylists.length,
                      itemExtent: 80.0,
                      itemBuilder: (context, index) {
                        final playlist = allPlaylists[index];
                        return _PlaylistTile(
                          key: ValueKey(playlist.id),
                          playlist: playlist,
                          allSongs: widget.allSongs,
                          onTap: () => _openPlaylist(context, playlist),
                          onLongPress: playlist.isSystemPlaylist
                              ? null
                              : () => _showPlaylistOptions(context, playlist),
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                          index: index,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.playlist_add_rounded,
            size: 64,
            color: colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No playlists yet',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first playlist',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final controller = TextEditingController();

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
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.pop(context);
              _createPlaylist(value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context);
                _createPlaylist(name);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createPlaylist(String name) async {
    try {
      final playlist = await _repo.createPlaylist(name);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Created "$name"'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => _openPlaylist(context, playlist),
          ),
        ),
      );

      _openPlaylist(context, playlist);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating playlist: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _openPlaylist(BuildContext context, Playlist playlist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaylistDetailScreen(
          playlist: playlist,
          allSongs: widget.allSongs,
          onSongSelected: widget.onSongSelected,
        ),
      ),
    );
  }

  void _showPlaylistOptions(BuildContext context, Playlist playlist) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
            ListTile(
              leading: Icon(Icons.edit_rounded, color: colorScheme.primary),
              title: Text('Rename', style: textTheme.bodyLarge),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(context, playlist);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_rounded, color: colorScheme.error),
              title: Text(
                'Delete',
                style: textTheme.bodyLarge?.copyWith(color: colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(context, playlist);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, Playlist playlist) {
    final controller = TextEditingController(text: playlist.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 50,
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.pop(context);
              _repo.renamePlaylist(playlist.id, value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context);
                _repo.renamePlaylist(playlist.id, name);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Playlist playlist) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Playlist?'),
        content: Text('Are you sure you want to delete "${playlist.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _repo.deletePlaylist(playlist.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Deleted "${playlist.name}"'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _CreatePlaylistButton extends StatelessWidget {
  final VoidCallback onPressed;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _CreatePlaylistButton({
    required this.onPressed,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.primary.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: colorScheme.onPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Create New Playlist',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  final Playlist playlist;
  final List<Song> allSongs;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final int index;

  const _PlaylistTile({
    super.key,
    required this.playlist,
    required this.allSongs,
    required this.onTap,
    this.onLongPress,
    required this.colorScheme,
    required this.textTheme,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final playlistSongs = allSongs
        .where((song) => playlist.songIds.contains(song.id))
        .toList();

    final duration = playlistSongs.fold<Duration>(
      Duration.zero,
      (sum, song) => sum + song.duration,
    );

    final durationText = _formatDuration(duration);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 200 + (index * 30)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              color: colorScheme.surfaceVariant.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      _buildPlaylistArtwork(playlistSongs),
                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                if (playlist.isSystemPlaylist)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Icon(
                                      Icons.favorite,
                                      size: 16,
                                      color: Colors.red,
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    playlist.name,
                                    style: textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${playlist.songCount} songs${durationText.isNotEmpty ? ' · $durationText' : ''}',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (onLongPress != null)
                        Icon(
                          Icons.more_vert,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaylistArtwork(List<Song> songs) {
    const size = 56.0;

    if (playlist.isSystemPlaylist) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade400, Colors.pink.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.favorite, color: Colors.white, size: 28),
      );
    }

    if (songs.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.music_note_rounded,
          color: colorScheme.onPrimaryContainer,
          size: 28,
        ),
      );
    }

    if (songs.length <= 3) {
      final song = songs.first;
      return Container(
        width: size,
        height: size,
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
                  cacheWidth: 150,
                  errorBuilder: (_, __, ___) => _defaultIcon(),
                ),
              )
            : _defaultIcon(),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 1,
            crossAxisSpacing: 1,
          ),
          itemCount: 4,
          itemBuilder: (context, index) {
            if (index < songs.length && songs[index].albumArtPath != null) {
              return Image.file(
                File(songs[index].albumArtPath!),
                fit: BoxFit.cover,
                cacheWidth: 75,
                errorBuilder: (_, __, ___) => Container(
                  color: colorScheme.surfaceVariant,
                  child: _defaultIcon(),
                ),
              );
            }
            return Container(
              color: colorScheme.surfaceVariant,
              child: _defaultIcon(),
            );
          },
        ),
      ),
    );
  }

  Widget _defaultIcon() {
    return Icon(
      Icons.music_note_rounded,
      color: colorScheme.onSurfaceVariant,
      size: 20,
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds == 0) return '';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}
