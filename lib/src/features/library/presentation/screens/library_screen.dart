import 'package:flutter/material.dart';

import '../../data/local_music_loader.dart';
import '../../data/playlist_repository.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/music_folder.dart';
import '../../domain/models/library_source_settings.dart';
import '../../domain/models/library_source_service.dart';
import '../widgets/tabs/songs_tab.dart';
import '../widgets/tabs/playlists_tab.dart';
import '../widgets/tabs/favorites_tab.dart';
import '../widgets/library_filter_bar.dart';
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
  final PlaylistRepository _playlistRepo = PlaylistRepository.instance;

  bool _useModernView = true;
  SortType currentSort = SortType.title;
  
  LibrarySourceSettings? _librarySourceSettings;
  List<MusicFolder> _availableFolders = [];
  List<Song> _currentSongs = [];
  
  bool _isInitializing = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _playlistRepo.initialize();
    _initializeLibrary();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeLibrary() async {
    try {
      // Load saved settings FIRST
      final savedSettings = await LibrarySourceService.load();
      
      // Load folders in parallel
      final folders = await LocalMusicLoader.instance.loadAvailableFolders();
      
      // Load songs with saved settings
      final songs = await LocalMusicLoader.instance.loadSongs(
        forceRefresh: true,
        sourceSettings: savedSettings,
      );

      if (mounted) {
        setState(() {
          _librarySourceSettings = savedSettings;
          _availableFolders = folders;
          _currentSongs = songs;
          _isInitializing = false;
        });
        
        widget.onSongsLoaded?.call(songs);
        
        // Debug: Show what was restored
        if (savedSettings.isAllMusic) {
          debugPrint('✅ Restored: All Music mode');
        } else {
          debugPrint('✅ Restored: ${savedSettings.folderPaths.length} folder(s) selected');
        }
      }
    } catch (e) {
      debugPrint('❌ Error initializing library: $e');
      if (mounted) {
        setState(() {
          _librarySourceSettings = const LibrarySourceSettings();
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    
    setState(() => _isRefreshing = true);
    
    try {
      final songs = await LocalMusicLoader.instance.loadSongs(
        forceRefresh: true,
        sourceSettings: _librarySourceSettings,
      );
      
      if (mounted) {
        setState(() {
          _currentSongs = songs;
          _isRefreshing = false;
        });
        widget.onSongsLoaded?.call(songs);
      }
    } catch (e) {
      debugPrint('❌ Error refreshing: $e');
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _handleFilterChange(LibrarySourceSettings newSettings) async {
    // Save immediately
    await LibrarySourceService.save(newSettings);
    
    setState(() {
      _librarySourceSettings = newSettings;
      _isRefreshing = true;
    });

    // Reload songs with new filter
    final songs = await LocalMusicLoader.instance.loadSongs(
      forceRefresh: true,
      sourceSettings: newSettings,
    );

    if (mounted) {
      setState(() {
        _currentSongs = songs;
        _isRefreshing = false;
      });
      widget.onSongsLoaded?.call(songs);
    }
  }

  Future<void> _openManageFolders() async {
    final result = await Navigator.push<LibrarySourceSettings>(
      context,
      MaterialPageRoute(
        builder: (context) => ManageMusicFoldersScreen(
          currentSettings: _librarySourceSettings ?? const LibrarySourceSettings(),
        ),
      ),
    );

    if (result != null) {
      await _handleFilterChange(result);
      
      // Reload folders list
      final folders = await LocalMusicLoader.instance.loadAvailableFolders();
      if (mounted) {
        setState(() => _availableFolders = folders);
      }
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

  String _currentSourceLabel() {
    if (_librarySourceSettings == null) return 'Loading...';
    
    if (_librarySourceSettings!.isAllMusic || 
        _librarySourceSettings!.folderPaths.isEmpty) {
      return 'All music on this device';
    }

    final count = _librarySourceSettings!.selectedFolderCount;
    return count == 1 ? '1 folder selected' : '$count folders selected';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isInitializing) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Library'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Loading your library...',
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(colorScheme, textTheme),
      body: Column(
        children: [
          if (_availableFolders.isNotEmpty && _librarySourceSettings != null)
            LibraryFilterBar(
              currentSettings: _librarySourceSettings!,
              availableFolders: _availableFolders,
              onSettingsChanged: _handleFilterChange,
              onManageFolders: _openManageFolders,
            ),

          Expanded(
            child: _isRefreshing
                ? Center(
                    child: CircularProgressIndicator(
                      color: colorScheme.primary,
                    ),
                  )
                : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_currentSongs.isEmpty) {
      return _buildEmptyState();
    }

    return TabBarView(
      controller: _tabController,
      children: [
        SongsTab(
          songs: _currentSongs,
          currentSort: currentSort,
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
    );
  }

  PreferredSizeWidget _buildAppBar(
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          const SizedBox(height: 2),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _currentSourceLabel(),
              key: ValueKey(_currentSourceLabel()),
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
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

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    final isFiltered = _librarySourceSettings?.isAllMusic == false &&
        _librarySourceSettings!.hasSelectedFolders;

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
            isFiltered
                ? 'No songs in selected folders'
                : 'Add music to your device',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          if (isFiltered) ...[
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: () async {
                await _handleFilterChange(
                  const LibrarySourceSettings(),
                );
              },
              child: const Text('Show All Music'),
            ),
          ],
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
