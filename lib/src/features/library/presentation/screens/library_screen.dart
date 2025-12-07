
import 'package:flutter/material.dart';

import '../../data/local_music_loader.dart';
import '../../data/playlist_repository.dart';
import '../../domain/entities/song.dart';
import '../widgets/tabs/songs_tab.dart';
import '../widgets/tabs/playlists_tab.dart';
import '../widgets/tabs/favorites_tab.dart';

enum SortType { title, artist, duration, dateAdded }

class LibraryScreen extends StatefulWidget {
  final void Function(Song song, List<Song> allSongs, int index) onSongSelected;
  final Function(List<Song>)? onSongsLoaded;

  const LibraryScreen({
    super.key,
    required this.onSongSelected,
    this.onSongsLoaded,
  });

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<Song>> _songsFuture;
  List<Song> _allSongs = [];

  final PlaylistRepository _playlistRepo = PlaylistRepository.instance;
  late TabController _tabController;

  bool _useModernView = true;

  SortType currentSort = SortType.title;

  @override
  void initState() {
    super.initState();
    _songsFuture = _loadSongs();
    _tabController = TabController(length: 3, vsync: this);
    _playlistRepo.initialize();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<List<Song>> _loadSongs() async {
    final songs = await LocalMusicLoader.instance.loadSongs();
    _allSongs = songs;
    widget.onSongsLoaded?.call(songs);
    return songs;
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _songsFuture = _loadSongs();
    });
    await _songsFuture;
  }

  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        return SafeArea(
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
                    Icon(Icons.sort_rounded, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Sort by',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SortOption(
                label: 'Title (A-Z)',
                icon: Icons.title_rounded,
                isSelected: currentSort == SortType.title,
                onTap: () {
                  setState(() => currentSort = SortType.title);
                  Navigator.pop(context);
                },
              ),
              _SortOption(
                label: 'Artist (A-Z)',
                icon: Icons.person_rounded,
                isSelected: currentSort == SortType.artist,
                onTap: () {
                  setState(() => currentSort = SortType.artist);
                  Navigator.pop(context);
                },
              ),
              _SortOption(
                label: 'Duration',
                icon: Icons.schedule_rounded,
                isSelected: currentSort == SortType.duration,
                onTap: () {
                  setState(() => currentSort = SortType.duration);
                  Navigator.pop(context);
                },
              ),
              _SortOption(
                label: 'Recently Added',
                icon: Icons.access_time_rounded,
                isSelected: currentSort == SortType.dateAdded,
                onTap: () {
                  setState(() => currentSort = SortType.dateAdded);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: _buildAppBar(colorScheme, textTheme),
      body: FutureBuilder<List<Song>>(
        future: _songsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState(colorScheme, textTheme);
          }

          if (snapshot.hasError) {
            return _buildErrorState(colorScheme, textTheme);
          }

          final songs = snapshot.data ?? [];

          if (songs.isEmpty) {
            return _buildEmptyState(colorScheme, textTheme);
          }

          return TabBarView(
            controller: _tabController,
            children: [
              SongsTab(
                songs: songs,
                currentSort: currentSort,
                onSongSelected: widget.onSongSelected,
                onRefresh: _handleRefresh,
              ),

              PlaylistsTab(
                allSongs: songs,
                onSongSelected: widget.onSongSelected,
              ),

              FavoritesTab(
                allSongs: songs,
                onSongSelected: widget.onSongSelected,
              ),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return AppBar(
      title: Row(
        children: [
          Icon(Icons.library_music_rounded, color: colorScheme.primary),
          const SizedBox(width: 12),
          Text(
            'Library',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 2,
      bottom: _useModernView
          ? TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Songs'),
                Tab(text: 'Playlists'),
                Tab(text: 'Favorites'),
              ],
              indicatorColor: colorScheme.primary,
              labelColor: colorScheme.primary,
              unselectedLabelColor: colorScheme.onSurface.withOpacity(0.6),
              labelStyle: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            )
          : null,
      actions: [
        IconButton(
          icon: const Icon(Icons.sort_rounded),
          onPressed: _showSortMenu,
          tooltip: 'Sort',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildLoadingState(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Loading your music...',
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading songs',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please try again',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_off_rounded,
            size: 64,
            color: colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No songs found',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add music to your device',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SortOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected
            ? colorScheme.primary
            : colorScheme.onSurface.withOpacity(0.6),
      ),
      title: Text(
        label,
        style: textTheme.bodyLarge?.copyWith(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? colorScheme.primary : null,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_rounded, color: colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}
