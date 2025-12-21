import 'package:flutter/material.dart';

import '../../data/local_music_loader.dart';
import '../../data/playlist_repository.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/music_folder.dart';
import '../../domain/models/library_source_settings.dart';
import '../../domain/models/library_source_service.dart';

import '../../presentation/widgets/library_filter_bar.dart';
import '../../presentation/widgets/library_stats_header.dart';
import '../../presentation/widgets/library_search_bar.dart';
import '../widgets/tabs/songs_tab.dart';
import '../widgets/tabs/playlists_tab.dart';
import '../widgets/tabs/favorites_tab.dart';

import './manage_music_folders_screen.dart';

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
  late TabController _tabController;
  late ScrollController _nestedScrollController;
  late TextEditingController _searchController;
  final PlaylistRepository _playlistRepo = PlaylistRepository.instance;

  SortType currentSort = SortType.title;

  LibrarySourceSettings? _librarySourceSettings;
  List<MusicFolder> _availableFolders = [];
  List<Song> _currentSongs = [];
  String _searchQuery = '';
  String _lastSearchQuery = '';

  bool _isInitializing = true;
  bool _isRefreshing = false;
  bool _needsSourceChoice = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController = TextEditingController();
    _nestedScrollController = ScrollController();
    _searchController.addListener(() {
      final query = _searchController.text;
      if (query != _searchQuery) {
        setState(() => _searchQuery = query);
      }
    });
    _playlistRepo.initialize();
    _initializeLibrary();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _nestedScrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeLibrary() async {
    try {
      final savedSettings = await LibrarySourceService.load();
      final folders = await LocalMusicLoader.instance.loadAvailableFolders();
      final hasExplicitSource =
          savedSettings.isAllMusic || savedSettings.folderPaths.isNotEmpty;

      if (!mounted) return;

      _librarySourceSettings = savedSettings;
      _availableFolders = folders;
      _isInitializing = false;
      _needsSourceChoice = !hasExplicitSource;

      setState(() {});

      if (hasExplicitSource) {
        await _showLoadingWhile(() async {
          _currentSongs = await LocalMusicLoader.instance.loadSongs(
            forceRefresh: false,
            sourceSettings: savedSettings,
          );
          widget.onSongsLoaded?.call(_currentSongs);
        });
      }
    } catch (e) {
      if (!mounted) return;
      _librarySourceSettings = const LibrarySourceSettings();
      _isInitializing = false;
      _needsSourceChoice = true;
      setState(() {});
    }
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing || _librarySourceSettings == null) return;
    setState(() => _isRefreshing = true);

    try {
      final songs = await LocalMusicLoader.instance.loadSongs(
        forceRefresh: true,
        sourceSettings: _librarySourceSettings!,
      );

      if (!mounted) return;
      _currentSongs = songs;
      _isRefreshing = false;
      setState(() {});
      widget.onSongsLoaded?.call(songs);
    } catch (e) {
      if (!mounted) return;
      _isRefreshing = false;
      setState(() {});
    }
  }

  String _getDynamicTitle() {
    if (_librarySourceSettings == null || _librarySourceSettings!.isAllMusic) {
      return 'Library';
    }

    final selectedPaths = _librarySourceSettings!.folderPaths;

    if (selectedPaths.isEmpty) return 'Library';

    if (selectedPaths.length == 1) {
      final path = selectedPaths.first;
      try {
        final folder = _availableFolders.firstWhere((f) => f.path == path);
        return folder.name;
      } catch (e) {
        return 'Folder';
      }
    }

    return '${selectedPaths.length} Folders';
  }

  Future<void> _handleFilterChange(LibrarySourceSettings newSettings) async {
    await LibrarySourceService.save(newSettings);
    await _showLoadingWhile(() async {
      final songs = await LocalMusicLoader.instance.loadSongs(
        forceRefresh: true,
        sourceSettings: newSettings,
      );
      if (!mounted) return;
      _currentSongs = songs;
      _librarySourceSettings = newSettings;
      _needsSourceChoice = false;
      setState(() {});
      widget.onSongsLoaded?.call(songs);
    });
  }

  Future<void> _openManageFolders() async {
    final result = await Navigator.push<LibrarySourceSettings>(
      context,
      MaterialPageRoute(
        builder: (context) => ManageMusicFoldersScreen(
          currentSettings:
              _librarySourceSettings ?? const LibrarySourceSettings(),
        ),
      ),
    );

    if (result != null && mounted) {
      await _handleFilterChange(result);
      final folders = await LocalMusicLoader.instance.loadAvailableFolders();
      if (mounted) {
        setState(() => _availableFolders = folders);
      }
    }
  }

  Future<void> _showLoadingWhile(Future<void> Function() task) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await task();
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
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
                  color: colorScheme.onSurface.withValues(alpha: 0.3),
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
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 360 || size.height < 700;
    final bool hasFilters =
        _availableFolders.isNotEmpty && _librarySourceSettings != null;
    final double expandedHeight = isCompact ? 220.0 : 260.0;

    if (_isInitializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_needsSourceChoice) {
      return Scaffold(
        appBar: AppBar(title: const Text("Library Setup")),
        body: _buildSourceChoice(),
      );
    }

    final int songCount = _currentSongs.length;
    final int totalDurationMs = _currentSongs.fold<int>(
      0,
      (int sum, Song song) => sum + song.duration.inMilliseconds,
    );
    final int artistCount = _currentSongs.map((s) => s.artist).toSet().length;

    // Reset scroll position when search query changes
    if (_searchQuery != _lastSearchQuery) {
      _lastSearchQuery = _searchQuery;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_nestedScrollController.hasClients) {
          // Scroll to collapsed position (just enough to show search results)
          // This keeps the stats card hidden and focuses on the song list
          final collapsedPosition = expandedHeight - kToolbarHeight - 48.0; // 48 = TabBar height
          _nestedScrollController.animateTo(
            collapsedPosition,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }

    return Scaffold(
      body: NestedScrollView(
        controller: _nestedScrollController,
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: expandedHeight,
              pinned: true,
              floating: false,
              elevation: 0,
              scrolledUnderElevation: 2,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              automaticallyImplyLeading: false,
              
              // Title when scrolled
              title: innerBoxIsScrolled 
                ? Text(
                    _getDynamicTitle(),
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
              centerTitle: false,

              actions: [
                IconButton(
                  icon: const Icon(Icons.sort_rounded),
                  onPressed: _showSortMenu,
                  tooltip: 'Sort',
                ),
                const SizedBox(width: 4),
              ],

              // Collapsible header content
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isCompact ? 16 : 20,
                      isCompact ? 8 : 12,
                      isCompact ? 16 : 20,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          _getDynamicTitle(),
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: isCompact
                                ? textTheme.headlineSmall?.fontSize
                                : textTheme.headlineMedium?.fontSize,
                          ),
                        ),
                        
                        SizedBox(height: isCompact ? 10 : 16),

                        // Stats card
                        LibraryStatsHeader(
                          songCount: songCount,
                          totalDuration: Duration(milliseconds: totalDurationMs),
                          artistCount: artistCount,
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                          isCompact: isCompact,
                        ),
                        SizedBox(height: isCompact ? 8 : 12),
                      ],
                    ),
                  ),
                ),
              ),

              // Tab bar at bottom
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: colorScheme.primary,
                labelColor: colorScheme.primary,
                unselectedLabelColor:
                    colorScheme.onSurface.withValues(alpha: 0.6),
                indicatorWeight: 3,
                labelStyle: (isCompact ? textTheme.bodySmall : textTheme.titleSmall)
                    ?.copyWith(fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Songs'),
                  Tab(text: 'Playlists'),
                  Tab(text: 'Favorites'),
                ],
              ),
            ),

            SliverPersistentHeader(
              pinned: true,
              delegate: _LibrarySearchFilterHeader(
                searchController: _searchController,
                searchQuery: _searchQuery,
                hasFilters: hasFilters,
                currentSettings: _librarySourceSettings,
                availableFolders: _availableFolders,
                onSettingsChanged:
                    hasFilters ? _handleFilterChange : (_) {},
                onManageFolders:
                    hasFilters ? _openManageFolders : () {},
                isCompact: isCompact,
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            SongsTab(
              songs: _currentSongs,
              currentSort: currentSort,
              searchQuery: _searchQuery,
              onSongSelected: widget.onSongSelected,
              onRefresh: _handleRefresh,
            ),
            PlaylistsTab(
              allSongs: _currentSongs,
              onSongSelected: widget.onSongSelected,
            ),
            FavoritesTab(
              allSongs: _currentSongs,
              onSongSelected: widget.onSongSelected,
            ),
          ],
        ),
      ),
    );
  }

  // Initial setup UI when no music source is selected
  Widget _buildSourceChoice() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.library_music_rounded,
              size: 80,
              color: colorScheme.primary.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 24),
            Text(
              'Choose your music source',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Select where to find your music files',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () =>
                  _handleFilterChange(const LibrarySourceSettings()),
              icon: const Icon(Icons.music_note_rounded),
              label: const Text('Scan all music'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openManageFolders,
              icon: const Icon(Icons.folder_rounded),
              label: const Text('Choose specific folders'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibrarySearchFilterHeader extends SliverPersistentHeaderDelegate {
  final TextEditingController searchController;
  final String searchQuery;
  final bool hasFilters;
  final LibrarySourceSettings? currentSettings;
  final List<MusicFolder> availableFolders;
  final Function(LibrarySourceSettings) onSettingsChanged;
  final VoidCallback onManageFolders;
  final bool isCompact;

  _LibrarySearchFilterHeader({
    required this.searchController,
    required this.searchQuery,
    required this.hasFilters,
    required this.currentSettings,
    required this.availableFolders,
    required this.onSettingsChanged,
    required this.onManageFolders,
    required this.isCompact,
  });

  double get _baseHeight => isCompact ? 76.0 : 88.0;
  double get _filtersHeight => hasFilters ? (isCompact ? 56.0 : 64.0) : 0.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: EdgeInsets.fromLTRB(16, isCompact ? 6 : 8, 16, isCompact ? 10 : 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LibrarySearchBar(
            controller: searchController,
            searchQuery: searchQuery,
            colorScheme: colorScheme,
            textTheme: textTheme,
            onClear: () => searchController.clear(),
          ),
          if (hasFilters && currentSettings != null) ...[
            SizedBox(height: isCompact ? 6 : 10),
            LibraryFilterBar(
              currentSettings: currentSettings!,
              availableFolders: availableFolders,
              onSettingsChanged: onSettingsChanged,
              onManageFolders: onManageFolders,
            ),
          ],
        ],
      ),
    );
  }

  @override
  double get maxExtent => _baseHeight + _filtersHeight;

  @override
  double get minExtent => _baseHeight + _filtersHeight;

  @override
  bool shouldRebuild(covariant _LibrarySearchFilterHeader oldDelegate) {
    return searchQuery != oldDelegate.searchQuery ||
        hasFilters != oldDelegate.hasFilters ||
        currentSettings != oldDelegate.currentSettings ||
        availableFolders.length != oldDelegate.availableFolders.length ||
        isCompact != oldDelegate.isCompact;
  }
}

// Sort option widget for bottom sheet menu
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
            : colorScheme.onSurface.withValues(alpha: 0.6),
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
