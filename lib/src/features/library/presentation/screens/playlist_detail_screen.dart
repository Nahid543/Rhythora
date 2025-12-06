import 'dart:io';
import 'package:flutter/material.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/playlist.dart';
import '../../data/playlist_repository.dart';
import '../widgets/song_list_item.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;
  final List<Song> allSongs;
  final Function(Song, List<Song>, int) onSongSelected;

  const PlaylistDetailScreen({
    super.key,
    required this.playlist,
    required this.allSongs,
    required this.onSongSelected,
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen>
    with SingleTickerProviderStateMixin {
  final PlaylistRepository _repo = PlaylistRepository.instance;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool _isReordering = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  List<Song> _getPlaylistSongs() {
    return _repo.getPlaylistSongs(widget.playlist, widget.allSongs);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      body: ValueListenableBuilder<List<Playlist>>(
        valueListenable: _repo.playlistsNotifier,
        builder: (context, playlists, _) {
          // Get updated playlist
          final currentPlaylist = widget.playlist.isSystemPlaylist
              ? _repo.getFavoritesAsPlaylist()
              : playlists.firstWhere(
                  (p) => p.id == widget.playlist.id,
                  orElse: () => widget.playlist,
                );

          final playlistSongs = _getPlaylistSongs();
          final totalDuration = playlistSongs.fold<Duration>(
            Duration.zero,
            (sum, song) => sum + song.duration,
          );

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // App Bar with Playlist Header
              _buildSliverAppBar(
                currentPlaylist,
                playlistSongs,
                totalDuration,
                colorScheme,
                textTheme,
                isTablet,
              ),

              // Action Buttons
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildActionButtons(
                    playlistSongs,
                    colorScheme,
                    textTheme,
                  ),
                ),
              ),

              // Song List
              if (playlistSongs.isEmpty)
                SliverFillRemaining(
                  child: _buildEmptyState(colorScheme, textTheme),
                )
              else if (_isReordering)
                _buildReorderableList(playlistSongs, colorScheme, textTheme)
              else
                _buildNormalList(playlistSongs, colorScheme, textTheme),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar(
    Playlist playlist,
    List<Song> songs,
    Duration totalDuration,
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isTablet,
  ) {
    final artworkSize = isTablet ? 240.0 : 180.0;

    return SliverAppBar(
      expandedHeight: isTablet ? 380 : 320,
      pinned: true,
      elevation: 0,
      backgroundColor: colorScheme.surface,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (_isReordering)
          TextButton.icon(
            onPressed: () => setState(() => _isReordering = false),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Done'),
          )
        else if (!playlist.isSystemPlaylist)
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => _showPlaylistOptions(playlist),
          ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colorScheme.primaryContainer.withOpacity(0.3),
                colorScheme.surface,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                top: 80,
                left: isTablet ? 48 : 24,
                right: isTablet ? 48 : 24,
              ),
              child: Column(
                children: [
                  // Playlist Artwork
                  Hero(
                    tag: 'playlist_${playlist.id}',
                    child: _buildPlaylistArtwork(
                      songs,
                      playlist.isSystemPlaylist,
                      artworkSize,
                      colorScheme,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Playlist Name
                  Text(
                    playlist.name,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Stats
                  Text(
                    '${songs.length} songs · ${_formatDuration(totalDuration)}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistArtwork(
    List<Song> songs,
    bool isSystemPlaylist,
    double size,
    ColorScheme colorScheme,
  ) {
    // Favorites - heart icon
    if (isSystemPlaylist) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade400, Colors.pink.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.3),
              blurRadius: 30,
              spreadRadius: 5,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Icon(
          Icons.favorite_rounded,
          color: Colors.white,
          size: size * 0.4,
        ),
      );
    }

    // Empty playlist
    if (songs.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.2),
              blurRadius: 30,
              spreadRadius: 5,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Icon(
          Icons.music_note_rounded,
          color: colorScheme.onPrimaryContainer,
          size: size * 0.4,
        ),
      );
    }

    // 1-3 songs - single artwork
    if (songs.length <= 3) {
      final song = songs.first;
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: colorScheme.surfaceVariant,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 30,
              spreadRadius: 5,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: song.albumArtPath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.file(
                  File(song.albumArtPath!),
                  fit: BoxFit.cover,
                  cacheWidth: size.toInt(),
                  errorBuilder: (_, __, ___) => _defaultIcon(colorScheme, size),
                ),
              )
            : _defaultIcon(colorScheme, size),
      );
    }

    // 4+ songs - 2x2 mosaic
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 30,
            spreadRadius: 5,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: 4,
          itemBuilder: (context, index) {
            if (index < songs.length && songs[index].albumArtPath != null) {
              return Image.file(
                File(songs[index].albumArtPath!),
                fit: BoxFit.cover,
                cacheWidth: (size / 2).toInt(),
                errorBuilder: (_, __, ___) => Container(
                  color: colorScheme.surfaceVariant,
                  child: Icon(
                    Icons.music_note_rounded,
                    color: colorScheme.onSurfaceVariant,
                    size: size * 0.15,
                  ),
                ),
              );
            }
            return Container(
              color: colorScheme.surfaceVariant,
              child: Icon(
                Icons.music_note_rounded,
                color: colorScheme.onSurfaceVariant,
                size: size * 0.15,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _defaultIcon(ColorScheme colorScheme, double size) {
    return Icon(
      Icons.music_note_rounded,
      color: colorScheme.onSurfaceVariant,
      size: size * 0.4,
    );
  }

  Widget _buildActionButtons(
    List<Song> songs,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          // Play Button
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: songs.isEmpty
                  ? null
                  : () => widget.onSongSelected(songs.first, songs, 0),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Play'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Shuffle Button
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: songs.isEmpty
                  ? null
                  : () {
                      // TODO: Implement shuffle
                      widget.onSongSelected(songs.first, songs, 0);
                    },
              icon: const Icon(Icons.shuffle_rounded),
              label: const Text('Shuffle'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Add Songs Button
          if (!widget.playlist.isSystemPlaylist)
            IconButton.filledTonal(
              onPressed: () => _showAddSongsSheet(),
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Add songs',
              style: IconButton.styleFrom(padding: const EdgeInsets.all(16)),
            ),

          // Reorder Button
          if (songs.length > 1 && !widget.playlist.isSystemPlaylist)
            IconButton.filledTonal(
              onPressed: () => setState(() => _isReordering = true),
              icon: const Icon(Icons.swap_vert_rounded),
              tooltip: 'Reorder',
              style: IconButton.styleFrom(padding: const EdgeInsets.all(16)),
            ),
        ],
      ),
    );
  }

  Widget _buildNormalList(
    List<Song> songs,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final song = songs[index];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 200 + (index * 30)),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: Dismissible(
                  key: ValueKey(song.id),
                  direction: widget.playlist.isSystemPlaylist
                      ? DismissDirection.none
                      : DismissDirection.endToStart,
                  background: Container(
                    color: colorScheme.error,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: Icon(
                      Icons.delete_rounded,
                      color: colorScheme.onError,
                    ),
                  ),
                  onDismissed: (_) {
                    _repo.removeSongFromPlaylist(widget.playlist.id, song.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Removed "${song.title}"'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: SongListItem(
                    song: song,
                    onTap: () => widget.onSongSelected(song, songs, index),
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                    index: index,
                    showTrailingNumber: true,
                    trailingNumber: index + 1,
                  ),
                ),
              ),
            );
          },
        );
      }, childCount: songs.length),
    );
  }

  Widget _buildReorderableList(
    List<Song> songs,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return SliverReorderableList(
      itemBuilder: (context, index) {
        final song = songs[index];
        return ReorderableDragStartListener(
          key: ValueKey(song.id),
          index: index,
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            elevation: 2,
            child: ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: colorScheme.surfaceVariant,
                ),
                child: song.albumArtPath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.file(
                          File(song.albumArtPath!),
                          fit: BoxFit.cover,
                          cacheWidth: 150,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.music_note,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.music_note,
                        color: colorScheme.onSurfaceVariant,
                      ),
              ),
              title: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Icon(
                Icons.drag_handle_rounded,
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
        );
      },
      itemCount: songs.length,
      onReorder: (oldIndex, newIndex) {
        if (oldIndex < newIndex) {
          newIndex -= 1;
        }
        _repo.reorderPlaylistSongs(widget.playlist.id, oldIndex, newIndex);
      },
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_note_rounded,
              size: 80,
              color: colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'No songs yet',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add songs to start building your playlist',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _showAddSongsSheet(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Songs'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSongsSheet() {
    final playlistSongIds = widget.playlist.songIds.toSet();
    final availableSongs = widget.allSongs
        .where((song) => !playlistSongIds.contains(song.id))
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddSongsSheet(
        availableSongs: availableSongs,
        onSongsSelected: (selectedIds) {
          _repo.addMultipleSongsToPlaylist(widget.playlist.id, selectedIds);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added ${selectedIds.length} songs'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  void _showPlaylistOptions(Playlist playlist) {
    final colorScheme = Theme.of(context).colorScheme;

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
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(playlist);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_rounded, color: colorScheme.error),
              title: Text('Delete', style: TextStyle(color: colorScheme.error)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(playlist);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(Playlist playlist) {
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
                _repo.renamePlaylist(playlist.id, name);
                Navigator.pop(context);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Playlist playlist) {
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
              _repo.deletePlaylist(playlist.id);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to library
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

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

// ============================================
// ADD SONGS SHEET
// ============================================

class _AddSongsSheet extends StatefulWidget {
  final List<Song> availableSongs;
  final Function(List<String>) onSongsSelected;

  const _AddSongsSheet({
    required this.availableSongs,
    required this.onSongsSelected,
  });

  @override
  State<_AddSongsSheet> createState() => _AddSongsSheetState();
}

class _AddSongsSheetState extends State<_AddSongsSheet> {
  final Set<String> _selectedSongIds = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Song> _getFilteredSongs() {
    if (_searchQuery.isEmpty) return widget.availableSongs;

    final query = _searchQuery.toLowerCase();
    return widget.availableSongs.where((song) {
      return song.title.toLowerCase().contains(query) ||
          song.artist.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final filteredSongs = _getFilteredSongs();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
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

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Add Songs',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (_selectedSongIds.isNotEmpty)
                  FilledButton.icon(
                    onPressed: () =>
                        widget.onSongsSelected(_selectedSongIds.toList()),
                    icon: const Icon(Icons.check_rounded),
                    label: Text('Add ${_selectedSongIds.length}'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search songs...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Song List
          Expanded(
            child: filteredSongs.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'All songs already in playlist'
                          : 'No results',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: filteredSongs.length,
                    itemExtent: 72.0,
                    itemBuilder: (context, index) {
                      final song = filteredSongs[index];
                      final isSelected = _selectedSongIds.contains(song.id);

                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (selected) {
                          setState(() {
                            if (selected == true) {
                              _selectedSongIds.add(song.id);
                            } else {
                              _selectedSongIds.remove(song.id);
                            }
                          });
                        },
                        secondary: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: colorScheme.surfaceVariant,
                          ),
                          child: song.albumArtPath != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.file(
                                    File(song.albumArtPath!),
                                    fit: BoxFit.cover,
                                    cacheWidth: 150,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.music_note,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.music_note,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                        ),
                        title: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
