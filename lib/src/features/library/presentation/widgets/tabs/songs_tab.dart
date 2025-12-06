// lib/src/features/library/presentation/widgets/tabs/songs_tab.dart

import 'dart:io';
import 'package:flutter/material.dart';

import '../../../domain/entities/song.dart';
import '../../screens/library_screen.dart';
import '../library_search_bar.dart';
import '../library_view_toggle.dart';
import '../library_stats_header.dart';
import '../song_list_item.dart';
import '../song_grid_item.dart';
import '../song_options_bottom_sheet.dart'; // ← NEW IMPORT

class SongsTab extends StatefulWidget {
  final List<Song> songs;
  final SortType currentSort;
  final Function(Song, List<Song>, int) onSongSelected;
  final Future<void> Function() onRefresh;

  const SongsTab({
    super.key,
    required this.songs,
    required this.currentSort,
    required this.onSongSelected,
    required this.onRefresh,
  });

  @override
  State<SongsTab> createState() => _SongsTabState();
}

class _SongsTabState extends State<SongsTab>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  LibraryViewType _currentView = LibraryViewType.list;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  bool get wantKeepAlive => true; // Keep state when switching tabs

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      final value = _searchController.text;
      if (value != _searchQuery) {
        setState(() {
          _searchQuery = value;
        });
      }
    });

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  List<Song> _getFilteredAndSortedSongs() {
    // Filter
    final query = _searchQuery.trim().toLowerCase();
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

    // Sort
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
        // Keep default order
        break;
    }

    return filtered;
  }

  // ← NEW METHOD: Show song options bottom sheet
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
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    final filteredSongs = _getFilteredAndSortedSongs();

    // Calculate stats
    final totalDuration = widget.songs.fold<Duration>(
      Duration.zero,
      (sum, song) => sum + song.duration,
    );
    final uniqueArtists = widget.songs.map((s) => s.artist).toSet().length;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: colorScheme.primary,
      child: Column(
        children: [
          // Search Bar
          FadeTransition(
            opacity: _fadeAnimation,
            child: LibrarySearchBar(
              controller: _searchController,
              searchQuery: _searchQuery,
              onClear: () => _searchController.clear(),
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
          ),

          // Stats Header
          FadeTransition(
            opacity: _fadeAnimation,
            child: LibraryStatsHeader(
              songCount: widget.songs.length,
              totalDuration: totalDuration,
              artistCount: uniqueArtists,
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
          ),

          // View Toggle
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

          // Song List/Grid
          Expanded(
            child: filteredSongs.isEmpty
                ? _buildNoResultsState(colorScheme, textTheme)
                : _currentView == LibraryViewType.list
                    ? _buildListView(
                        filteredSongs, widget.songs, colorScheme, textTheme)
                    : _buildGridView(filteredSongs, widget.songs, colorScheme,
                        textTheme, isTablet),
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
  ) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: filteredSongs.length,
      itemExtent: 72.0, // Fixed height for performance
      itemBuilder: (context, index) {
        final song = filteredSongs[index];
        final fullIndex = allSongs.indexWhere((s) => s.id == song.id);
        final queueIndex = fullIndex == -1 ? index : fullIndex;

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
                  onLongPress: () => _showSongOptions(song), // ← ADDED
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
                  onLongPress: () => _showSongOptions(song), // ← ADDED
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

  Widget _buildNoResultsState(ColorScheme colorScheme, TextTheme textTheme) {
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
            'No results for "$_searchQuery"',
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
