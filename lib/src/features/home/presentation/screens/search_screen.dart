import 'dart:async';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../../library/domain/entities/song.dart';

enum SearchFilter { all, songs, artists, albums }

class SearchScreen extends StatefulWidget {
  final List<Song> allSongs;
  final Function(Song, List<Song>, int) onSongSelected;

  const SearchScreen({
    super.key,
    required this.allSongs,
    required this.onSongSelected,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  
  List<Song> _searchResults = [];
  List<String> _recentSearches = [];
  SearchFilter _currentFilter = SearchFilter.all;
  bool _isSearching = false;
  
  Timer? _debounce;
  String _lastSavedQuery = '';
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
    
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    final lowercaseQuery = query.toLowerCase().trim();
    List<Song> results = widget.allSongs.where((song) {
      final matchesTitle = song.title.toLowerCase().contains(lowercaseQuery);
      final matchesArtist = song.artist.toLowerCase().contains(lowercaseQuery);
      final matchesAlbum = song.album.toLowerCase().contains(lowercaseQuery);

      switch (_currentFilter) {
        case SearchFilter.all:
          return matchesTitle || matchesArtist || matchesAlbum;
        case SearchFilter.songs:
          return matchesTitle;
        case SearchFilter.artists:
          return matchesArtist;
        case SearchFilter.albums:
          return matchesAlbum;
      }
    }).toList();

    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  void _saveToRecentSearches(String query) {
    final trimmedQuery = query.trim();
    
    if (trimmedQuery.isEmpty || 
        trimmedQuery.length < 2 || 
        trimmedQuery == _lastSavedQuery) {
      return;
    }

    setState(() {
      _recentSearches.remove(trimmedQuery);
      _recentSearches.insert(0, trimmedQuery);
      if (_recentSearches.length > 10) {
        _recentSearches = _recentSearches.sublist(0, 10);
      }
      _lastSavedQuery = trimmedQuery;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _isSearching = false;
    });
    _searchFocus.requestFocus();
  }

  void _handleRecentSearch(String query) {
    _searchController.text = query;
    _performSearch(query);
  }

  void _removeRecentSearch(String query) {
    setState(() {
      _recentSearches.remove(query);
    });
  }

  void _clearAllRecentSearches() {
    setState(() {
      _recentSearches.clear();
      _lastSavedQuery = '';
    });
  }

  void _handleSongTap(Song song, int queueIndex) {
    _saveToRecentSearches(_searchController.text);
    widget.onSongSelected(song, widget.allSongs, queueIndex);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Search',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 2,
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              isTablet ? 32 : 20,
              16,
              isTablet ? 32 : 20,
              8,
            ),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _SearchBarWidget(
                controller: _searchController,
                focusNode: _searchFocus,
                onChanged: _onSearchChanged,
                onClear: _clearSearch,
                onSubmitted: (query) {
                  _performSearch(query);
                  _saveToRecentSearches(query);
                },
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 20),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _SearchFilterChip(
                      label: 'All',
                      isSelected: _currentFilter == SearchFilter.all,
                      onTap: () {
                        setState(() => _currentFilter = SearchFilter.all);
                        _performSearch(_searchController.text);
                      },
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    ),
                    const SizedBox(width: 8),
                    _SearchFilterChip(
                      label: 'Songs',
                      icon: Icons.music_note_rounded,
                      isSelected: _currentFilter == SearchFilter.songs,
                      onTap: () {
                        setState(() => _currentFilter = SearchFilter.songs);
                        _performSearch(_searchController.text);
                      },
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    ),
                    const SizedBox(width: 8),
                    _SearchFilterChip(
                      label: 'Artists',
                      icon: Icons.person_rounded,
                      isSelected: _currentFilter == SearchFilter.artists,
                      onTap: () {
                        setState(() => _currentFilter = SearchFilter.artists);
                        _performSearch(_searchController.text);
                      },
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    ),
                    const SizedBox(width: 8),
                    _SearchFilterChip(
                      label: 'Albums',
                      icon: Icons.album_rounded,
                      isSelected: _currentFilter == SearchFilter.albums,
                      onTap: () {
                        setState(() => _currentFilter = SearchFilter.albums);
                        _performSearch(_searchController.text);
                      },
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: _buildContent(colorScheme, textTheme, isTablet),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ColorScheme colorScheme, TextTheme textTheme, bool isTablet) {
    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Searching...',
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    if (_searchController.text.isNotEmpty) {
      if (_searchResults.isEmpty) {
        return _buildEmptyState(colorScheme, textTheme);
      }
      return _buildSearchResults(colorScheme, textTheme, isTablet);
    }

    return _buildRecentSearches(colorScheme, textTheme, isTablet);
  }

  Widget _buildSearchResults(ColorScheme colorScheme, TextTheme textTheme, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 20),
          child: Text(
            '${_searchResults.length} result${_searchResults.length != 1 ? 's' : ''} found',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 20),
            physics: const BouncingScrollPhysics(),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final song = _searchResults[index];
              final fullIndex = widget.allSongs.indexWhere((s) => s.id == song.id);
              final queueIndex = fullIndex == -1 ? index : fullIndex;
              
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 200 + (index * 50)),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: _SearchResultItem(
                        song: song,
                        query: _searchController.text,
                        onTap: () => _handleSongTap(song, queueIndex),
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentSearches(ColorScheme colorScheme, TextTheme textTheme, bool isTablet) {
    if (_recentSearches.isEmpty) {
      return _buildEmptyState(colorScheme, textTheme, isRecent: true);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton(
                onPressed: _clearAllRecentSearches,
                child: const Text('Clear all'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 20),
            physics: const BouncingScrollPhysics(),
            itemCount: _recentSearches.length,
            itemBuilder: (context, index) {
              final query = _recentSearches[index];
              return _RecentSearchItem(
                query: query,
                onTap: () => _handleRecentSearch(query),
                onRemove: () => _removeRecentSearch(query),
                colorScheme: colorScheme,
                textTheme: textTheme,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, TextTheme textTheme, {bool isRecent = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isRecent ? Icons.history_rounded : Icons.search_off_rounded,
              size: 64,
              color: colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isRecent ? 'No recent searches' : 'No results found',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              isRecent
                  ? 'Your search history will appear here'
                  : 'Try searching with different keywords or change the filter',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(String) onChanged;
  final Function(String) onSubmitted;
  final VoidCallback onClear;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _SearchBarWidget({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        style: textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: 'Search songs, artists, albums...',
          hintStyle: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.5),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: colorScheme.primary,
            size: 24,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                  onPressed: onClear,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

class _SearchFilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _SearchFilterChip({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outline.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 18,
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResultItem extends StatelessWidget {
  final Song song;
  final String query;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _SearchResultItem({
    required this.song,
    required this.query,
    required this.onTap,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final artworkId = int.tryParse(song.id) ?? 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: colorScheme.surfaceVariant.withOpacity(0.3),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: QueryArtworkWidget(
                    id: artworkId,
                    type: ArtworkType.AUDIO,
                    artworkFit: BoxFit.cover,
                    artworkBorder: BorderRadius.zero,
                    nullArtworkWidget: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.primary.withOpacity(0.7),
                            colorScheme.secondary.withOpacity(0.5),
                          ],
                        ),
                      ),
                      child: Icon(
                        Icons.music_note_rounded,
                        color: colorScheme.onPrimary,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 14,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.play_circle_outline_rounded,
                color: colorScheme.primary,
                size: 32,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentSearchItem extends StatelessWidget {
  final String query;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _RecentSearchItem({
    required this.query,
    required this.onTap,
    required this.onRemove,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: colorScheme.surfaceVariant.withOpacity(0.3),
          ),
          child: Row(
            children: [
              Icon(
                Icons.history_rounded,
                color: colorScheme.onSurface.withOpacity(0.6),
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  query,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: colorScheme.onSurface.withOpacity(0.6),
                  size: 20,
                ),
                onPressed: onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
