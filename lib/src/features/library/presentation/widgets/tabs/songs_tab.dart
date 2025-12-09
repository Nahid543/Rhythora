
import 'package:flutter/material.dart';

import '../../../domain/entities/song.dart';
import '../../screens/library_screen.dart';
import '../library_view_toggle.dart';
import '../song_list_item.dart';
import '../song_grid_item.dart';
import '../song_options_bottom_sheet.dart';
import '../../../../../core/services/battery_saver_service.dart';

class SongsTab extends StatefulWidget {
  final List<Song> songs;
  final SortType currentSort;
  final String searchQuery;
  final Function(Song, List<Song>, int) onSongSelected;
  final Future<void> Function() onRefresh;

  const SongsTab({
    super.key,
    required this.songs,
    required this.currentSort,
    required this.searchQuery,
    required this.onSongSelected,
    required this.onRefresh,
  });

  @override
  State<SongsTab> createState() => _SongsTabState();
}

class _SongsTabState extends State<SongsTab>
    with AutomaticKeepAliveClientMixin {
  LibraryViewType _currentView = LibraryViewType.list;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  List<Song> _getFilteredAndSortedSongs() {
    final query = widget.searchQuery.trim().toLowerCase();
    List<Song> filtered;
    if (query.isEmpty) {
      filtered = widget.songs;
    } else {
      filtered = widget.songs.where((song) {
        final title = song.title.toLowerCase();
        final artist = song.artist.toLowerCase();
        final album = song.album.toLowerCase();
        return title.contains(query) ||
            artist.contains(query) ||
            album.contains(query);
      }).toList();
    }

    switch (widget.currentSort) {
      case SortType.title:
        filtered.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case SortType.artist:
        filtered.sort((a, b) =>
            a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
        break;
      case SortType.duration:
        filtered.sort((a, b) => b.duration.compareTo(a.duration));
        break;
      case SortType.dateAdded:
        break;
    }

    return filtered;
  }

  void _showSongOptions(Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SongOptionsBottomSheet(
        song: song,
        allSongs: widget.songs,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final animationsEnabled = BatterySaverService.instance.shouldUseAnimations;

    final filteredSongs = _getFilteredAndSortedSongs();

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: colorScheme.primary,
      child: Column(
        children: [
          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  filteredSongs.length == widget.songs.length
                      ? '${widget.songs.length} songs'
                      : '${filteredSongs.length} of ${widget.songs.length} songs',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const Spacer(),
                LibraryViewToggle(
                  currentView: _currentView,
                  onViewChanged: (view) {
                    setState(() => _currentView = view);
                  },
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
              ],
            ),
          ),

          Expanded(
            child: filteredSongs.isEmpty
                ? _buildNoResultsState(
                    colorScheme,
                    textTheme,
                    widget.searchQuery,
                  )
                : _currentView == LibraryViewType.list
                    ? _buildListView(
                        filteredSongs,
                        widget.songs,
                        colorScheme,
                        textTheme,
                        animationsEnabled,
                      )
                    : _buildGridView(
                        filteredSongs,
                        widget.songs,
                        colorScheme,
                        textTheme,
                        isTablet,
                        animationsEnabled,
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(
    List<Song> filteredSongs,
    List<Song> allSongs,
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool animationsEnabled,
  ) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: filteredSongs.length,
      itemExtent: 72.0,
      itemBuilder: (context, index) {
        final song = filteredSongs[index];
        final fullIndex = allSongs.indexWhere((s) => s.id == song.id);
        final queueIndex = fullIndex == -1 ? index : fullIndex;

        if (!animationsEnabled) {
          return SongListItem(
            song: song,
            onTap: () => widget.onSongSelected(song, allSongs, queueIndex),
            onLongPress: () => _showSongOptions(song),
            colorScheme: colorScheme,
            textTheme: textTheme,
            index: index,
          );
        }

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 200 + (index * 30)),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: SongListItem(
                  song: song,
                  onTap: () => widget.onSongSelected(song, allSongs, queueIndex),
                  onLongPress: () => _showSongOptions(song),
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  index: index,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGridView(
    List<Song> filteredSongs,
    List<Song> allSongs,
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isTablet,
    bool animationsEnabled,
  ) {
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isTablet ? 4 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: filteredSongs.length,
      itemBuilder: (context, index) {
        final song = filteredSongs[index];
        final fullIndex = allSongs.indexWhere((s) => s.id == song.id);
        final queueIndex = fullIndex == -1 ? index : fullIndex;

        if (!animationsEnabled) {
          return SongGridItem(
            song: song,
            onTap: () => widget.onSongSelected(song, allSongs, queueIndex),
            onLongPress: () => _showSongOptions(song),
            colorScheme: colorScheme,
            textTheme: textTheme,
          );
        }

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 200 + (index * 30)),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.scale(
                scale: 0.8 + (0.2 * value),
                child: SongGridItem(
                  song: song,
                  onTap: () => widget.onSongSelected(song, allSongs, queueIndex),
                  onLongPress: () => _showSongOptions(song),
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNoResultsState(
    ColorScheme colorScheme,
    TextTheme textTheme,
    String searchQuery,
  ) {
    final trimmedQuery = searchQuery.trim();
    final message =
        trimmedQuery.isEmpty ? 'No results' : 'No results for "$trimmedQuery"';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
